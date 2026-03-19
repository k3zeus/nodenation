#!/usr/bin/env bash
#
# Sistema Wireless - Sqlite3 | Ghost Nodes v0.3 18032026
#
# ─────────────────────────────────────────────────────────────────────────────
# wpa_import.sh
# Lê /etc/wpa_supplicant/wpa_supplicant.conf, extrai pares SSID+PSK e
# atualiza o campo "password" no banco wifi_scan.db onde o SSID coincidir.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuração ─────────────────────────────────────────────────────────────
DB_DIR="/home/pleb/halfin"
DB="$DB_DIR/wifi_scan.db"
LOG="$DB_DIR/log_scan_wifi.log"
WPA_CONF="${1:-/etc/wpa_supplicant/wpa_supplicant.conf}"

# ─── Verificações iniciais ────────────────────────────────────────────────────
if [ ! -f "$DB" ]; then
    echo "[ERRO] Banco de dados não encontrado: $DB"
    echo "       Execute wifi_scan.sh primeiro."
    exit 1
fi

if [ ! -f "$WPA_CONF" ]; then
    echo "[ERRO] Arquivo wpa_supplicant não encontrado: $WPA_CONF"
    echo "       Uso: $0 [/caminho/para/wpa_supplicant.conf]"
    exit 1
fi

if [ ! -r "$WPA_CONF" ]; then
    echo "[ERRO] Sem permissão de leitura em: $WPA_CONF"
    echo "       Tente: sudo $0"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  WPA Import — lendo: $WPA_CONF"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TMP_SQL="$(mktemp /tmp/wpa_import_sql.XXXXXX)"
trap 'rm -f "$TMP_SQL"' EXIT

echo "BEGIN TRANSACTION;" > "$TMP_SQL"

# ─── Parse do wpa_supplicant.conf ─────────────────────────────────────────────
# Extrai blocos network={...} e coleta ssid= e psk=
ssid=""
psk=""
found=0
updated=0
skipped=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # Limpa espaços e tabs à esquerda
    line="${line#"${line%%[![:space:]]*}"}"

    # Início de bloco network
    if [[ "$line" == "network={"* ]]; then
        ssid=""
        psk=""
        continue
    fi

    # Fim de bloco — processa par ssid+psk
    if [[ "$line" == "}" ]]; then
        if [[ -n "$ssid" && -n "$psk" ]]; then
            ((found++)) || true

            # Remove aspas do SSID se houver
            ssid_clean="${ssid//\"/}"

            # Escapa aspas simples para SQLite
            ssid_sql="${ssid_clean//\'/\'\'}"
            psk_sql="${psk//\'/\'\'}"

            # Verifica se o SSID existe no banco
            exists=$(sqlite3 "$DB" "SELECT COUNT(*) FROM networks WHERE ssid='${ssid_sql}';")

            if [[ "$exists" -gt 0 ]]; then
                cat >> "$TMP_SQL" <<ENDSQL
UPDATE networks
   SET password  = '${psk_sql}',
       last_seen = CURRENT_TIMESTAMP
 WHERE ssid = '${ssid_sql}';
ENDSQL
                echo "  [✔] SSID encontrado no banco  → '${ssid_clean}'"
                ((updated++)) || true
            else
                echo "  [–] SSID não está no banco    → '${ssid_clean}' (não foi escaneado ainda)"
                ((skipped++)) || true
            fi
        fi
        ssid=""
        psk=""
        continue
    fi

    # Captura ssid=
    if [[ "$line" =~ ^ssid= ]]; then
        ssid="${line#ssid=}"
        ssid="${ssid//\"/}"   # remove aspas
        continue
    fi

    # Captura psk= (senha em texto plano ou hash)
    if [[ "$line" =~ ^psk= ]]; then
        psk="${line#psk=}"
        psk="${psk//\"/}"
        continue
    fi

done < "$WPA_CONF"

echo "COMMIT;" >> "$TMP_SQL"

# ─── Executa SQL ──────────────────────────────────────────────────────────────
sqlite3 "$DB" < "$TMP_SQL"

# ─── Resumo ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Blocos network encontrados : $found"
echo "  Senhas atualizadas no banco: $updated"
echo "  SSIDs não encontrados (DB) : $skipped"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "$(date '+%F %T') - wpa_import: $found blocos lidos, $updated senhas atualizadas, $skipped ignorados." >> "$LOG"

exit 0
