#!/usr/bin/env bash
#
# Sistema Wireless - Sqlite3 | Ghost Nodes v0.3 18032026
#
# ─────────────────────────────────────────────────────────────────────────────
# wifi_show.sh
# Exibe o conteúdo do banco wifi_scan.db no terminal com formatação e filtros.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DB_DIR="/home/pleb/halfin"
DB="$DB_DIR/wifi_scan.db"

# ─── Cores ANSI ───────────────────────────────────────────────────────────────
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
MAGENTA="\e[35m"
WHITE="\e[97m"

# ─── Verificação ──────────────────────────────────────────────────────────────
if [ ! -f "$DB" ]; then
    echo -e "${RED}[ERRO]${RESET} Banco não encontrado: $DB"
    echo       "       Execute wifi_scan.sh primeiro."
    exit 1
fi

# ─── Argumentos opcionais ─────────────────────────────────────────────────────
MODE="${1:-all}"        # all | known | hidden | open
SORT="${2:-last_seen}"  # last_seen | ssid | channel | security | bssid

# ─── Cabeçalho ────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║            WiFi Scan — Banco de Dados               ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${DIM}Banco:${RESET} $DB"
echo -e "  ${DIM}Modo:${RESET}  $MODE  ${DIM}| Ordem:${RESET} $SORT"
echo ""

# ─── Monta cláusula WHERE conforme modo ───────────────────────────────────────
case "$MODE" in
    known)   WHERE="WHERE password IS NOT NULL AND password != ''" ;;
    hidden)  WHERE="WHERE ssid IS NULL OR ssid = ''" ;;
    open)    WHERE="WHERE security = '' OR security = '--'" ;;
    *)       WHERE="" ;;
esac

# ─── Estatísticas rápidas ─────────────────────────────────────────────────────
TOTAL=$(sqlite3  "$DB" "SELECT COUNT(*)                                        FROM networks;")
KNOWN=$(sqlite3  "$DB" "SELECT COUNT(*) FROM networks WHERE password IS NOT NULL AND password != '';")
HIDDEN=$(sqlite3 "$DB" "SELECT COUNT(*) FROM networks WHERE ssid IS NULL OR ssid = '';")
OPEN=$(sqlite3   "$DB" "SELECT COUNT(*) FROM networks WHERE security = '' OR security = '--';")

echo -e "  ${BOLD}Estatísticas:${RESET}"
echo -e "  ${WHITE}Total de redes :${RESET} ${BOLD}$TOTAL${RESET}"
echo -e "  ${GREEN}Com senha salva:${RESET} ${BOLD}$KNOWN${RESET}"
echo -e "  ${YELLOW}SSID oculto    :${RESET} ${BOLD}$HIDDEN${RESET}"
echo -e "  ${RED}Rede aberta    :${RESET} ${BOLD}$OPEN${RESET}"
echo ""

# ─── Linha separadora ─────────────────────────────────────────────────────────
echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
printf "  ${BOLD}${CYAN}%-4s %-19s %-28s %-6s %-5s %-14s %-12s %-20s${RESET}\n" \
       "ID" "BSSID" "SSID" "MODO" "CANAL" "SEGURANÇA" "SENHA" "ÚLTIMO SCAN"
echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"

# ─── Query principal ──────────────────────────────────────────────────────────
sqlite3 -separator $'\x01' "$DB" \
    "SELECT id, bssid,
            COALESCE(NULLIF(ssid,''), '[oculto]'),
            COALESCE(NULLIF(mode,''), '?'),
            COALESCE(CAST(channel AS TEXT), '?'),
            COALESCE(NULLIF(security,''), 'ABERTA'),
            COALESCE(NULLIF(password,''), '—'),
            strftime('%d/%m/%y %H:%M', last_seen)
     FROM networks
     $WHERE
     ORDER BY $SORT DESC;" \
| while IFS=$'\x01' read -r id bssid ssid mode chan sec pwd seen; do

    # Colore senha
    if [[ "$pwd" == "—" ]]; then
        pwd_col="${DIM}${pwd}${RESET}"
    else
        pwd_col="${GREEN}${BOLD}✔${RESET} ${pwd}"
    fi

    # Colore segurança
    case "$sec" in
        ABERTA) sec_col="${RED}${sec}${RESET}" ;;
        *WPA3*) sec_col="${GREEN}${sec}${RESET}" ;;
        *WPA2*) sec_col="${YELLOW}${sec}${RESET}" ;;
        *WPA*)  sec_col="${YELLOW}${sec}${RESET}" ;;
        *)      sec_col="${DIM}${sec}${RESET}" ;;
    esac

    # Trunca SSID longo
    ssid_disp="${ssid:0:27}"

    printf "  ${DIM}%-4s${RESET} %-19s ${BOLD}%-28s${RESET} %-6s %-5s %-23s %-21s ${DIM}%s${RESET}\n" \
           "$id" "$bssid" "$ssid_disp" "$mode" "$chan" \
           "$(echo -e "$sec_col")" \
           "$(echo -e "$pwd_col")" \
           "$seen"
done

echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────────────────────────────────${RESET}"
echo ""

# ─── Ajuda de uso ─────────────────────────────────────────────────────────────
echo -e "  ${DIM}Uso: $0 [modo] [ordem]${RESET}"
echo -e "  ${DIM}  Modos : all | known | hidden | open${RESET}"
echo -e "  ${DIM}  Ordem : last_seen | ssid | channel | security | bssid${RESET}"
echo -e "  ${DIM}  Ex:   $0 known ssid${RESET}"
echo ""

exit 0
