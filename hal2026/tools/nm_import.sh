#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# nm_import.sh - Ghost Nodes v0.1 19032026
# Lê os arquivos de conexão em /etc/NetworkManager/system-connections/,
# extrai SSID, BSSID e senha (psk), compara com o banco wifi_scan.db e:
#   - Atualiza senha se o registro existe mas está sem senha
#   - Atualiza senha se o registro existe mas a senha está diferente
#   - Insere novo registro se a rede não existe no banco
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuração ─────────────────────────────────────────────────────────────
DB_DIR="/home/pleb/halfin"
DB="$DB_DIR/wifi_scan.db"
LOG="$DB_DIR/log_scan_wifi.log"
NM_DIR="${1:-/etc/NetworkManager/system-connections}"

# ─── Cores ────────────────────────────────────────────────────────────────────
BOLD="\e[1m"
RESET="\e[0m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
DIM="\e[2m"
BLUE="\e[34m"

# ─── Cabeçalho ────────────────────────────────────────────────────────────────
clear
printf "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║     NetworkManager Import → wifi_scan.db             ║"
echo "  ╚══════════════════════════════════════════════════════╝"
printf "${RESET}\n"

# ─── Verificações iniciais ────────────────────────────────────────────────────
if [ ! -f "$DB" ]; then
    printf "${RED}[ERRO]${RESET} Banco não encontrado: %s\n" "$DB"
    echo       "       Execute wifi_scan.sh primeiro para criar o banco."
    exit 1
fi

if [ ! -d "$NM_DIR" ]; then
    printf "${RED}[ERRO]${RESET} Diretório não encontrado: %s\n" "$NM_DIR"
    exit 1
fi

if [ ! -r "$NM_DIR" ]; then
    printf "${RED}[ERRO]${RESET} Sem permissão de leitura em: %s\n" "$NM_DIR"
    echo       "       Tente: sudo $0"
    exit 1
fi

printf "  ${DIM}Diretório NM :${RESET} %s\n" "$NM_DIR"
printf "  ${DIM}Banco SQLite :${RESET} %s\n\n" "$DB"

# ─── Lista arquivos de conexão WiFi ───────────────────────────────────────────
# NM usa arquivos .nmconnection (Bookworm) ou sem extensão (legado)
mapfile -t NM_FILES < <(
    find "$NM_DIR" -maxdepth 1 -type f \( -name "*.nmconnection" -o -name "*" \) \
    2>/dev/null | sort
)

if [ ${#NM_FILES[@]} -eq 0 ]; then
    printf "${YELLOW}[AVISO]${RESET} Nenhum arquivo de conexão encontrado em %s\n" "$NM_DIR"
    exit 0
fi

printf "  ${DIM}Arquivos encontrados: %d${RESET}\n\n" "${#NM_FILES[@]}"

# ─── Separador de tabela ──────────────────────────────────────────────────────
SEP="${DIM}  ──────────────────────────────────────────────────────────────────────────${RESET}"

printf "  ${BOLD}${CYAN}%-30s %-20s %-10s %s${RESET}\n" \
       "SSID" "BSSID" "Tipo conn" "Ação"
printf "%b\n" "$SEP"

# ─── Contadores ───────────────────────────────────────────────────────────────
CNT_SKIP=0
CNT_INSERT=0
CNT_UPDATE_PWD=0
CNT_UPDATE_ALL=0
CNT_NO_CHANGE=0

TMP_SQL="$(mktemp /tmp/nm_import_sql.XXXXXX)"
trap 'rm -f "$TMP_SQL"' EXIT

echo "BEGIN TRANSACTION;" > "$TMP_SQL"

# ─── Processa cada arquivo ────────────────────────────────────────────────────
for FILE in "${NM_FILES[@]}"; do

    # Só processa se for arquivo legível
    [ -f "$FILE" ] && [ -r "$FILE" ] || continue

    # ── Extrai campos do arquivo .nmconnection (formato INI) ──────────────────
    # Tipo de conexão (wifi, ethernet, etc.)
    CONN_TYPE=$(awk -F= '/^\[connection\]/,/^\[/{if(/^type=/) print $2}' "$FILE" \
                | tr -d '[:space:]' | head -1)

    # Só processa conexões WiFi
    if [ "$CONN_TYPE" != "wifi" ]; then
        continue
    fi

    # SSID (pode estar em texto ou em hex)
    SSID_RAW=$(awk -F= '/^\[wifi\]/,/^\[/{if(/^ssid=/) print $2}' "$FILE" \
               | head -1 | sed 's/\r//')

    # BSSID (MAC específico, opcional)
    BSSID_RAW=$(awk -F= '/^\[wifi\]/,/^\[/{if(/^bssid=/) print $2}' "$FILE" \
                | head -1 | sed 's/\r//' | tr '[:lower:]' '[:upper:]')

    # Modo (infrastructure, ap, adhoc)
    MODE_RAW=$(awk -F= '/^\[wifi\]/,/^\[/{if(/^mode=/) print $2}' "$FILE" \
               | head -1 | sed 's/\r//')

    # Senha PSK em texto plano
    PSK_RAW=$(awk -F= '/^\[wifi-security\]/,/^\[/{if(/^psk=/) print $2}' "$FILE" \
              | head -1 | sed 's/\r//')

    # Tipo de segurança
    KEY_MGMT=$(awk -F= '/^\[wifi-security\]/,/^\[/{if(/^key-mgmt=/) print $2}' "$FILE" \
               | head -1 | sed 's/\r//')

    # Converte key-mgmt em label de segurança
    case "$KEY_MGMT" in
        wpa-psk)  SECURITY="WPA2" ;;
        sae)      SECURITY="WPA3" ;;
        wpa-eap)  SECURITY="WPA2-Enterprise" ;;
        none)     SECURITY="ABERTA" ;;
        "")       SECURITY="" ;;
        *)        SECURITY="$KEY_MGMT" ;;
    esac

    # Se não tem SSID, pula
    if [ -z "$SSID_RAW" ]; then
        continue
    fi

    SSID="$SSID_RAW"
    BSSID="${BSSID_RAW:-}"
    MODE="${MODE_RAW:-infrastructure}"
    PSK="${PSK_RAW:-}"

    # Escapa aspas simples para SQLite
    SSID_SQL="${SSID//\'/\'\'}"
    BSSID_SQL="${BSSID//\'/\'\'}"
    PSK_SQL="${PSK//\'/\'\'}"
    MODE_SQL="${MODE//\'/\'\'}"
    SEC_SQL="${SECURITY//\'/\'\'}"

    # ── Consulta o banco ──────────────────────────────────────────────────────
    # Busca por BSSID (mais preciso) ou por SSID
    if [ -n "$BSSID" ]; then
        DB_ROW=$(sqlite3 -separator $'\x01' "$DB" \
            "SELECT id, ssid, bssid, password, security FROM networks
             WHERE bssid='${BSSID_SQL}' OR ssid='${SSID_SQL}'
             LIMIT 1;" 2>/dev/null || echo "")
    else
        DB_ROW=$(sqlite3 -separator $'\x01' "$DB" \
            "SELECT id, ssid, bssid, password, security FROM networks
             WHERE ssid='${SSID_SQL}'
             LIMIT 1;" 2>/dev/null || echo "")
    fi

    SSID_DISP="${SSID:0:29}"

    # ── Decide ação ───────────────────────────────────────────────────────────
    if [ -z "$DB_ROW" ]; then
        # ── Rede NÃO existe no banco → INSERT ─────────────────────────────────
        ACTION_COLOR="${BLUE}"
        ACTION_LABEL="inserida"

        cat >> "$TMP_SQL" <<ENDSQL
INSERT INTO networks (bssid, ssid, mode, channel, security, password, last_seen)
  VALUES (
    '${BSSID_SQL}',
    '${SSID_SQL}',
    '${MODE_SQL}',
    NULL,
    '${SEC_SQL}',
    '${PSK_SQL}',
    CURRENT_TIMESTAMP
  )
  ON CONFLICT(bssid) DO UPDATE SET
    ssid      = excluded.ssid,
    mode      = excluded.mode,
    security  = CASE WHEN excluded.security != '' THEN excluded.security ELSE networks.security END,
    password  = CASE WHEN excluded.password != '' THEN excluded.password ELSE networks.password END,
    last_seen = CURRENT_TIMESTAMP;
ENDSQL
        CNT_INSERT=$((CNT_INSERT + 1))

    else
        # ── Rede existe → analisa o que precisa atualizar ─────────────────────
        IFS=$'\x01' read -r DB_ID DB_SSID DB_BSSID DB_PWD DB_SEC <<< "$DB_ROW"

        NEEDS_UPDATE=0
        UPDATE_FIELDS=""
        UPDATE_REASON=""

        # Senha ausente ou diferente
        if [ -z "$DB_PWD" ] && [ -n "$PSK" ]; then
            UPDATE_FIELDS="password='${PSK_SQL}'"
            UPDATE_REASON="sem senha → senha adicionada"
            NEEDS_UPDATE=1
            ACTION_COLOR="${GREEN}"
            ACTION_LABEL="senha adicionada"
            CNT_UPDATE_PWD=$((CNT_UPDATE_PWD + 1))

        elif [ -n "$PSK" ] && [ "$DB_PWD" != "$PSK" ]; then
            UPDATE_FIELDS="password='${PSK_SQL}'"
            UPDATE_REASON="senha desatualizada → atualizada"
            NEEDS_UPDATE=1
            ACTION_COLOR="${YELLOW}"
            ACTION_LABEL="senha atualizada"
            CNT_UPDATE_PWD=$((CNT_UPDATE_PWD + 1))
        fi

        # Segurança ausente ou diferente
        if [ -n "$SECURITY" ] && [ "$DB_SEC" != "$SECURITY" ]; then
            if [ -n "$UPDATE_FIELDS" ]; then
                UPDATE_FIELDS="${UPDATE_FIELDS}, security='${SEC_SQL}'"
            else
                UPDATE_FIELDS="security='${SEC_SQL}'"
            fi
            UPDATE_REASON="${UPDATE_REASON:+$UPDATE_REASON + }segurança atualizada"
            NEEDS_UPDATE=1
            [ -z "$ACTION_LABEL" ] && ACTION_LABEL="segurança atualizada"
            [ -z "$ACTION_COLOR" ] && ACTION_COLOR="${YELLOW}"
            CNT_UPDATE_ALL=$((CNT_UPDATE_ALL + 1))
        fi

        if [ "$NEEDS_UPDATE" -eq 1 ]; then
            cat >> "$TMP_SQL" <<ENDSQL
UPDATE networks
   SET ${UPDATE_FIELDS},
       last_seen = CURRENT_TIMESTAMP
 WHERE id = ${DB_ID};
ENDSQL
        else
            ACTION_COLOR="${DIM}"
            ACTION_LABEL="sem alteração"
            CNT_NO_CHANGE=$((CNT_NO_CHANGE + 1))
        fi
    fi

    # ── Exibe linha da tabela ─────────────────────────────────────────────────
    BSSID_DISP="${BSSID:-—}"
    printf "  ${BOLD}%-30s${RESET} %-20s %-10s ${ACTION_COLOR}%s${RESET}\n" \
           "$SSID_DISP" "$BSSID_DISP" "$SECURITY" "$ACTION_LABEL"

done

echo "COMMIT;" >> "$TMP_SQL"

# ─── Executa SQL ──────────────────────────────────────────────────────────────
printf "%b\n" "$SEP"
echo ""
printf "${CYAN}[*]${RESET} Aplicando alterações no banco...\n"
sqlite3 "$DB" < "$TMP_SQL"
printf "${GREEN}[✔]${RESET} Banco atualizado.\n\n"

# ─── Resumo ───────────────────────────────────────────────────────────────────
printf "${BOLD}${CYAN}"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Resumo da Importação"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "${RESET}"
printf "  ${BLUE}Redes inseridas (novas)   :${RESET} ${BOLD}%d${RESET}\n" "$CNT_INSERT"
printf "  ${GREEN}Senhas adicionadas        :${RESET} ${BOLD}%d${RESET}\n" "$CNT_UPDATE_PWD"
printf "  ${YELLOW}Campos atualizados        :${RESET} ${BOLD}%d${RESET}\n" "$CNT_UPDATE_ALL"
printf "  ${DIM}Sem alteração             :${RESET} ${BOLD}%d${RESET}\n"   "$CNT_NO_CHANGE"
echo ""

TOTAL_DB=$(sqlite3 "$DB" "SELECT COUNT(*) FROM networks;")
printf "  Total de redes no banco   : ${BOLD}%s${RESET}\n\n" "$TOTAL_DB"

echo "$(date '+%F %T') - nm_import: inseridas=$CNT_INSERT, senhas_add=$CNT_UPDATE_PWD, atualizadas=$CNT_UPDATE_ALL, sem_alteracao=$CNT_NO_CHANGE" >> "$LOG"

exit 0