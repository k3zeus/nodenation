#!/usr/bin/env bash
#
# Sistema Wireless - Sqlite3 | Ghost Nodes v0.3 18032026
#
# ─────────────────────────────────────────────────────────────────────────────
# wifi_connect.sh
# Escaneia redes próximas, compara com o banco wifi_scan.db,
# e oferece menu numerado para conectar usando nmcli.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DB_DIR="/home/pleb/halfin"
DB="$DB_DIR/wifi_scan.db"
LOG="$DB_DIR/log_scan_wifi.log"

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
BLUE="\e[34m"

# ─── Funções auxiliares ───────────────────────────────────────────────────────
header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║           WiFi Connect — Menu Interativo             ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

press_enter() {
    echo ""
    echo -e "  ${DIM}Pressione ENTER para continuar...${RESET}"
    read -r
}

# ─── Verificações iniciais ────────────────────────────────────────────────────
if [ ! -f "$DB" ]; then
    echo -e "${RED}[ERRO]${RESET} Banco não encontrado: $DB"
    echo       "       Execute wifi_scan.sh primeiro."
    exit 1
fi

if ! command -v nmcli &>/dev/null; then
    echo -e "${RED}[ERRO]${RESET} nmcli não encontrado. Instale o NetworkManager."
    exit 1
fi

# ─── Lista interfaces WiFi disponíveis ────────────────────────────────────────
select_interface() {
    header
    echo -e "  ${BOLD}Interfaces WiFi disponíveis:${RESET}"
    echo ""

    mapfile -t IFACES < <(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1}')

    if [ ${#IFACES[@]} -eq 0 ]; then
        echo -e "  ${RED}Nenhuma interface WiFi encontrada.${RESET}"
        exit 1
    fi

    for i in "${!IFACES[@]}"; do
        state=$(nmcli -t -f DEVICE,STATE device status | awk -F: -v dev="${IFACES[$i]}" '$1==dev{print $2}')
        conn=$(nmcli -t -f DEVICE,CONNECTION device status | awk -F: -v dev="${IFACES[$i]}" '$1==dev{print $2}')
        conn="${conn:-(desconectado)}"
        printf "  ${BOLD}[%d]${RESET}  %-12s  ${DIM}%s${RESET}  →  ${CYAN}%s${RESET}\n" \
               "$((i+1))" "${IFACES[$i]}" "$state" "$conn"
    done

    echo ""
    echo -e "  ${DIM}─────────────────────────────────────${RESET}"
    printf "  Escolha a interface [1-%d]: " "${#IFACES[@]}"
    read -r CHOICE

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#IFACES[@]} )); then
        echo -e "${RED}  Opção inválida.${RESET}"
        press_enter
        select_interface
        return
    fi

    IFACE="${IFACES[$((CHOICE-1))]}"
    echo -e "  ${GREEN}✔ Interface selecionada: ${BOLD}$IFACE${RESET}"
    sleep 1
}

# ─── Escaneia redes próximas ──────────────────────────────────────────────────
scan_networks() {
    header
    echo -e "  ${YELLOW}⟳ Escaneando redes próximas com a interface ${BOLD}$IFACE${RESET}${YELLOW}...${RESET}"
    echo ""

    # Força rescan
    nmcli device wifi rescan ifname "$IFACE" 2>/dev/null || true
    sleep 2

    # Captura redes: BSSID|SSID|CHAN|SECURITY|SIGNAL
    mapfile -t RAW_NETS < <(
        nmcli --escape no -t -f BSSID,SSID,CHAN,SECURITY,SIGNAL device wifi list ifname "$IFACE" 2>/dev/null \
        | grep -E '^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:' \
        | awk '{
            bssid = substr($0,1,17)
            rest  = substr($0,19)
            n = split(rest, f, ":")
            ssid     = (n>=1 ? f[1] : "")
            chan     = (n>=2 ? f[2] : "?")
            security = (n>=3 ? f[3] : "")
            signal   = (n>=4 ? f[4] : "0")
            if (ssid == "--") ssid = ""
            print bssid "|" ssid "|" chan "|" security "|" signal
        }' \
        | sort -t'|' -k5 -rn   # ordena por sinal decrescente
    )

    if [ ${#RAW_NETS[@]} -eq 0 ]; then
        echo -e "  ${RED}Nenhuma rede encontrada.${RESET}"
        press_enter
        return 1
    fi

    echo -e "  ${GREEN}✔ ${#RAW_NETS[@]} redes encontradas.${RESET}"
    sleep 1
    return 0
}

# ─── Exibe menu de redes e permite escolha ────────────────────────────────────
show_menu() {
    header
    echo -e "  ${BOLD}Interface: ${CYAN}$IFACE${RESET}  ${DIM}|  Redes próximas:${RESET}"
    echo ""
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────────────────────${RESET}"
    printf "  ${BOLD}${CYAN}%-4s %-19s %-28s %-5s %-14s %-6s %-5s${RESET}\n" \
           "Nº" "BSSID" "SSID" "CANAL" "SEGURANÇA" "SINAL" "SENHA?"
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────────────────────${RESET}"

    declare -ga MENU_NETS=()

    for i in "${!RAW_NETS[@]}"; do
        IFS='|' read -r bssid ssid chan security signal <<< "${RAW_NETS[$i]}"

        num=$((i+1))
        ssid_disp="${ssid:0:27}"
        [ -z "$ssid_disp" ] && ssid_disp="[oculto]"

        # Barra de sinal
        sig_int="${signal//[^0-9]/}"
        sig_int="${sig_int:-0}"
        if   (( sig_int >= 75 )); then sig_bar="${GREEN}████${RESET}"
        elif (( sig_int >= 50 )); then sig_bar="${YELLOW}███░${RESET}"
        elif (( sig_int >= 25 )); then sig_bar="${YELLOW}██░░${RESET}"
        else                           sig_bar="${RED}█░░░${RESET}"
        fi

        # Cor segurança
        case "$security" in
            *WPA3*) sec_col="${GREEN}$security${RESET}" ;;
            *WPA2*) sec_col="${YELLOW}$security${RESET}" ;;
            *WPA*)  sec_col="${YELLOW}$security${RESET}" ;;
            ""|--) sec_col="${RED}ABERTA${RESET}"; security="ABERTA" ;;
            *)      sec_col="${DIM}$security${RESET}" ;;
        esac

        # Verifica se está no banco e tem senha
        ssid_sql="${ssid//\'/\'\'}"
        bssid_sql="${bssid//\'/\'\'}"
        db_info=$(sqlite3 "$DB" \
            "SELECT COALESCE(password,''), COALESCE(ssid,'') FROM networks
             WHERE bssid='${bssid_sql}' OR ssid='${ssid_sql}'
             LIMIT 1;" 2>/dev/null || echo "|")

        IFS='|' read -r db_pwd db_ssid <<< "$db_info"

        if [[ -n "$db_pwd" ]]; then
            known_col="${GREEN}${BOLD}✔ sim${RESET}"
            MENU_NETS+=("${bssid}|${ssid}|${chan}|${security}|${signal}|${db_pwd}|known")
        else
            known_col="${DIM}não${RESET}"
            MENU_NETS+=("${bssid}|${ssid}|${chan}|${security}|${signal}||unknown")
        fi

        printf "  ${BOLD}[%-2d]${RESET} %-19s ${CYAN}${BOLD}%-28s${RESET} %-5s %-23s %-15s %s\n" \
               "$num" "$bssid" "$ssid_disp" "$chan" \
               "$(echo -e "$sec_col")" \
               "$(echo -e "$sig_bar $sig_int%")" \
               "$(echo -e "$known_col")"
    done

    echo -e "${DIM}  ──────────────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${DIM}[r] Reatualizar scan   [i] Trocar interface   [q] Sair${RESET}"
    echo ""
    printf "  Escolha uma rede [1-%d] ou opção: " "${#MENU_NETS[@]}"
    read -r CHOICE

    case "$CHOICE" in
        q|Q) echo -e "\n  ${DIM}Saindo...${RESET}\n"; exit 0 ;;
        r|R) scan_networks && show_menu; return ;;
        i|I) select_interface && scan_networks && show_menu; return ;;
        *)
            if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#MENU_NETS[@]} )); then
                echo -e "${RED}  Opção inválida.${RESET}"
                press_enter
                show_menu
                return
            fi
            connect_to "$((CHOICE-1))"
            ;;
    esac
}

# ─── Conecta à rede escolhida ─────────────────────────────────────────────────
connect_to() {
    local idx="$1"
    IFS='|' read -r bssid ssid chan security signal db_pwd status <<< "${MENU_NETS[$idx]}"

    header
    echo -e "  ${BOLD}Conectando a:${RESET}"
    echo ""
    echo -e "  ${DIM}BSSID   :${RESET} ${BOLD}$bssid${RESET}"
    echo -e "  ${DIM}SSID    :${RESET} ${BOLD}${ssid:-(oculto)}${RESET}"
    echo -e "  ${DIM}Canal   :${RESET} $chan"
    echo -e "  ${DIM}Segurança:${RESET} $security"
    echo -e "  ${DIM}Interface:${RESET} $IFACE"
    echo ""

    PASSWORD=""

    # ─── Rede aberta ──────────────────────────────────────────────────────────
    if [[ "$security" == "ABERTA" || -z "$security" ]]; then
        echo -e "  ${YELLOW}⚠ Rede aberta — sem senha necessária.${RESET}"
        echo ""
        printf "  Confirma conexão? [s/N]: "
        read -r CONFIRM
        [[ "$CONFIRM" =~ ^[sS]$ ]] || { show_menu; return; }

        echo -e "  ${CYAN}⟳ Conectando...${RESET}"
        if nmcli device wifi connect "$bssid" ifname "$IFACE" 2>&1; then
            echo -e "  ${GREEN}${BOLD}✔ Conectado com sucesso!${RESET}"
            echo "$(date '+%F %T') - Conectado (aberta) SSID='$ssid' BSSID='$bssid' via $IFACE" >> "$LOG"
        else
            echo -e "  ${RED}✘ Falha na conexão.${RESET}"
        fi
        press_enter
        show_menu
        return
    fi

    # ─── Rede com senha já no banco ───────────────────────────────────────────
    if [[ -n "$db_pwd" ]]; then
        echo -e "  ${GREEN}✔ Senha encontrada no banco de dados.${RESET}"
        echo ""
        printf "  Usar senha salva? [S/n]: "
        read -r USE_SAVED
        if [[ ! "$USE_SAVED" =~ ^[nN]$ ]]; then
            PASSWORD="$db_pwd"
        fi
    fi

    # ─── Pede senha manualmente ───────────────────────────────────────────────
    if [[ -z "$PASSWORD" ]]; then
        echo ""
        printf "  ${BOLD}Digite a senha para '${ssid}':${RESET} "
        read -rs PASSWORD
        echo ""

        if [[ -z "$PASSWORD" ]]; then
            echo -e "  ${RED}Senha vazia. Operação cancelada.${RESET}"
            press_enter
            show_menu
            return
        fi

        # Pergunta se quer salvar no banco
        echo ""
        printf "  Salvar senha no banco de dados? [s/N]: "
        read -r SAVE_PWD
        if [[ "$SAVE_PWD" =~ ^[sS]$ ]]; then
            pwd_sql="${PASSWORD//\'/\'\'}"
            bssid_sql="${bssid//\'/\'\'}"
            ssid_sql="${ssid//\'/\'\'}"
            sqlite3 "$DB" \
                "UPDATE networks SET password='${pwd_sql}', last_seen=CURRENT_TIMESTAMP
                 WHERE bssid='${bssid_sql}' OR ssid='${ssid_sql}';"
            echo -e "  ${GREEN}✔ Senha salva no banco.${RESET}"
        fi
    fi

    # ─── Executa conexão ──────────────────────────────────────────────────────
    echo ""
    echo -e "  ${CYAN}⟳ Conectando...${RESET}"

    if [[ -n "$ssid" ]]; then
        CONNECT_OUT=$(nmcli device wifi connect "$ssid" password "$PASSWORD" ifname "$IFACE" 2>&1) && RC=0 || RC=$?
    else
        CONNECT_OUT=$(nmcli device wifi connect "$bssid" password "$PASSWORD" ifname "$IFACE" 2>&1) && RC=0 || RC=$?
    fi

    echo ""
    if [[ $RC -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✔ Conectado com sucesso!${RESET}"
        echo -e "  ${DIM}$CONNECT_OUT${RESET}"
        echo "$(date '+%F %T') - Conectado SSID='$ssid' BSSID='$bssid' via $IFACE" >> "$LOG"
    else
        echo -e "  ${RED}${BOLD}✘ Falha na conexão:${RESET}"
        echo -e "  ${RED}$CONNECT_OUT${RESET}"
        echo "$(date '+%F %T') - FALHA ao conectar SSID='$ssid' BSSID='$bssid' via $IFACE: $CONNECT_OUT" >> "$LOG"
    fi

    press_enter
    show_menu
}

# ─── Fluxo principal ──────────────────────────────────────────────────────────
select_interface
scan_networks && show_menu

exit 0
