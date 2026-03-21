#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════╗
# ║       tools/system.sh — Painel de Sistema                    ║
# ║       Ghost Node Nation / Halfin                             ║
# ║       Chamado por: ghostnode → Menu 1.1                      ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Exibe em tempo real:
#   - Identificação do sistema (OS, kernel, hostname, uptime)
#   - Hardware (modelo, CPU, memória, temperatura)
#   - Usuários do sistema
#   - Espaço em disco
#   - Dados de rede (interfaces, IPs, Wi-Fi)
#   - Serviços instalados (ativos, inativos, com erro)
#   - Processos relevantes
#   - Relógio em tempo real ao final
#
# Uso standalone: bash tools/system.sh
#

# ══════════════════════════════════════════════════════════════════════════════
# CORES E SÍMBOLOS — mesmos do ghostnode para conformidade visual
# ══════════════════════════════════════════════════════════════════════════════
BOLD="\e[1m";    RESET="\e[0m";    DIM="\e[2m"
GREEN="\e[32m";  YELLOW="\e[33m";  RED="\e[31m"
CYAN="\e[36m";   MAGENTA="\e[35m"; WHITE="\e[97m"
BLUE="\e[34m"
CHECK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
WARN="${YELLOW}⚠${RESET}"
ARROW="${CYAN}▶${RESET}"
BULLET="${DIM}•${RESET}"

# ══════════════════════════════════════════════════════════════════════════════
# FUNÇÕES DE UI — helpers visuais
# ══════════════════════════════════════════════════════════════════════════════

# Linha separadora pesada
sep() {
    printf "${DIM}  ──────────────────────────────────────────────────────────────${RESET}\n"
}

# Linha separadora leve (pontilhada)
sep_thin() {
    printf "${DIM}  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄${RESET}\n"
}

# Cabeçalho de seção com ícone e título
section() {
    local ICON="$1"
    local TITLE="$2"
    echo ""
    printf "${BOLD}${MAGENTA}  ┌─ %s  %s${RESET}\n" "$ICON" "$TITLE"
    sep_thin
}

# Linha de dado: label + valor colorido
row() {
    # $1 = label, $2 = valor, $3 = cor opcional (default WHITE)
    local COLOR="${3:-$WHITE}"
    printf "  ${DIM}%-22s${RESET} ${COLOR}${BOLD}%s${RESET}\n" "$1" "$2"
}

# Linha de dado com badge de status (ok/warn/err)
row_status() {
    # $1 = label, $2 = valor, $3 = status (ok|warn|err)
    case "${3:-ok}" in
        ok)   BADGE="${CHECK}"; COLOR="$GREEN" ;;
        warn) BADGE="${WARN}";  COLOR="$YELLOW" ;;
        err)  BADGE="${CROSS}"; COLOR="$RED"    ;;
        *)    BADGE="${BULLET}"; COLOR="$WHITE" ;;
    esac
    printf "  %-22s ${COLOR}%s${RESET}  %b\n" "$1" "$2" "$BADGE"
}

# Barra de uso percentual (ex: disco, memória)
# $1 = label, $2 = porcentagem numérica (0-100), $3 = texto extra
bar_usage() {
    local LABEL="$1"
    local PCT="${2:-0}"
    local EXTRA="${3:-}"
    local FILLED=$(( PCT * 20 / 100 ))
    local EMPTY=$(( 20 - FILLED ))
    local BAR=""
    local COLOR

    # Cor da barra conforme uso
    if   [ "$PCT" -ge 90 ]; then COLOR="$RED"
    elif [ "$PCT" -ge 70 ]; then COLOR="$YELLOW"
    else                          COLOR="$GREEN"
    fi

    # Monta a barra
    local i=0
    while [ $i -lt $FILLED ]; do BAR="${BAR}█"; i=$((i+1)); done
    while [ $i -lt 20 ];      do BAR="${BAR}░"; i=$((i+1)); done

    printf "  ${DIM}%-22s${RESET} ${COLOR}%s${RESET} ${BOLD}%3d%%${RESET}  ${DIM}%s${RESET}\n" \
           "$LABEL" "$BAR" "$PCT" "$EXTRA"
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 1 — IDENTIFICAÇÃO DO SISTEMA
# Lê: /etc/os-release, hostname, uname, uptime, /proc/uptime
# ══════════════════════════════════════════════════════════════════════════════
bloco_sistema() {
    section "🖥 " "Identificação do Sistema"

    # Nome do OS a partir do arquivo padrão Debian
    OS_NAME=$(grep PRETTY_NAME /etc/os-release 2>/dev/null \
              | cut -d'"' -f2 || echo "desconhecido")

    # Versão do kernel
    KERNEL=$(uname -r 2>/dev/null || echo "—")

    # Arquitetura (arm64, x86_64, etc)
    ARCH=$(uname -m 2>/dev/null || echo "—")

    # Hostname atual
    HOSTNAME_NOW=$(hostname 2>/dev/null || echo "—")

    # Uptime legível
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "—")

    # Data e hora atual
    DATETIME=$(date '+%d/%m/%Y  %H:%M:%S')

    # Fuso horário
    TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null \
               || cat /etc/timezone 2>/dev/null \
               || echo "—")

    # Último boot
    LAST_BOOT=$(who -b 2>/dev/null | awk '{print $3, $4}' || echo "—")

    row "Sistema:"      "$OS_NAME"
    row "Kernel:"       "$KERNEL"
    row "Arquitetura:"  "$ARCH"
    row "Hostname:"     "$HOSTNAME_NOW"
    row "Uptime:"       "$UPTIME"
    row "Data/Hora:"    "$DATETIME"
    row "Fuso Horário:" "$TIMEZONE"
    row "Último Boot:"  "$LAST_BOOT"
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 2 — HARDWARE
# Lê: /proc/device-tree/model, /proc/cpuinfo, /proc/meminfo,
#      lscpu, free, sensors ou /sys/class/thermal
# ══════════════════════════════════════════════════════════════════════════════
bloco_hardware() {
    section "⚙ " "Hardware"

    # Modelo da placa (OrangePi, Raspberry Pi, etc) via device-tree
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' \
            || cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0' \
            || echo "Não detectado")

    row "Modelo:" "$MODEL"

    # ── CPU ──────────────────────────────────────────────────────────────────
    # Número de núcleos lógicos
    CPU_CORES=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "?")

    # Nome/modelo do processador
    CPU_MODEL=$(grep -m1 "^Model name\|^Hardware\|^Processor\|^model name" /proc/cpuinfo 2>/dev/null \
                | cut -d: -f2 | sed 's/^ *//' | head -1 || echo "—")
    [ -z "$CPU_MODEL" ] && CPU_MODEL=$(lscpu 2>/dev/null \
                | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')

    # Frequência atual (em MHz, convertida para GHz)
    CPU_FREQ=$(grep -m1 "^cpu MHz\|^BogoMIPS" /proc/cpuinfo 2>/dev/null \
               | awk -F: '{printf "%.2f GHz", $2/1000}' || echo "—")

    # Carga atual do sistema (load average 1 min)
    LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "—")
    LOAD_ALL=$(cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3}' || echo "—")

    row "CPU Modelo:"   "${CPU_MODEL:-—}"
    row "CPU Núcleos:"  "$CPU_CORES"
    row "CPU Freq:"     "$CPU_FREQ"
    row "Load Average:" "$LOAD_ALL  ${DIM}(1/5/15 min)${RESET}"

    # ── Temperatura ───────────────────────────────────────────────────────────
    # Tenta lm-sensors primeiro, depois sysfs
    TEMP="N/A"
    TEMP_STATUS="ok"

    if command -v sensors &>/dev/null; then
        TEMP=$(sensors 2>/dev/null \
               | awk '/^(CPU|cpu_thermal|temp1|Package id|Tdie|Tctl)/{
                   match($0,/\+([0-9.]+)/,a)
                   if(a[1]!="") { print a[1]"°C"; exit }
               }')
    fi

    # Fallback via sysfs (OrangePi, RPi, etc)
    if [ -z "$TEMP" ] || [ "$TEMP" = "N/A" ]; then
        for TFILE in \
            /sys/class/thermal/thermal_zone0/temp \
            /sys/devices/virtual/thermal/thermal_zone0/temp \
            /sys/bus/platform/drivers/sun8i-ths/*/temp1_input; do
            [ -f "$TFILE" ] && {
                RAW=$(cat "$TFILE" 2>/dev/null)
                # Valores acima de 1000 estão em milligraus
                [ "$RAW" -gt 1000 ] 2>/dev/null \
                    && TEMP="$(( RAW / 1000 ))°C" \
                    || TEMP="${RAW}°C"
                break
            }
        done
    fi

    # Alerta se temperatura alta (acima de 70°C)
    TEMP_NUM=$(echo "$TEMP" | tr -d '°C' | cut -d'.' -f1)
    if [ -n "$TEMP_NUM" ] && [ "$TEMP_NUM" -ge 80 ] 2>/dev/null; then
        TEMP_STATUS="err"
    elif [ -n "$TEMP_NUM" ] && [ "$TEMP_NUM" -ge 70 ] 2>/dev/null; then
        TEMP_STATUS="warn"
    fi

    row_status "Temperatura:" "$TEMP" "$TEMP_STATUS"

    # ── Memória ───────────────────────────────────────────────────────────────
    # Lê /proc/meminfo para valores precisos em kB
    MEM_TOTAL_KB=$(awk '/^MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
    MEM_AVAIL_KB=$(awk '/^MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
    MEM_USED_KB=$(( MEM_TOTAL_KB - MEM_AVAIL_KB ))

    MEM_TOTAL_MB=$(( MEM_TOTAL_KB / 1024 ))
    MEM_USED_MB=$(( MEM_USED_KB / 1024 ))
    MEM_FREE_MB=$(( MEM_AVAIL_KB / 1024 ))

    # Percentual de uso para a barra
    MEM_PCT=0
    [ "$MEM_TOTAL_KB" -gt 0 ] && MEM_PCT=$(( MEM_USED_KB * 100 / MEM_TOTAL_KB ))

    echo ""
    bar_usage "Memória RAM:" "$MEM_PCT" \
              "${MEM_USED_MB}MB usados de ${MEM_TOTAL_MB}MB (livre: ${MEM_FREE_MB}MB)"

    # Swap
    SWAP_TOTAL_KB=$(awk '/^SwapTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
    SWAP_FREE_KB=$(awk '/^SwapFree/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
    SWAP_USED_KB=$(( SWAP_TOTAL_KB - SWAP_FREE_KB ))
    SWAP_PCT=0
    [ "$SWAP_TOTAL_KB" -gt 0 ] && SWAP_PCT=$(( SWAP_USED_KB * 100 / SWAP_TOTAL_KB ))

    SWAP_TOTAL_MB=$(( SWAP_TOTAL_KB / 1024 ))
    SWAP_USED_MB=$(( SWAP_USED_KB / 1024 ))

    if [ "$SWAP_TOTAL_KB" -gt 0 ]; then
        bar_usage "Swap:" "$SWAP_PCT" \
                  "${SWAP_USED_MB}MB usados de ${SWAP_TOTAL_MB}MB"
    else
        printf "  ${DIM}%-22s${RESET} ${DIM}sem swap configurado${RESET}\n" "Swap:"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 3 — USUÁRIOS DO SISTEMA
# Lê: /etc/passwd, who, last, id
# ══════════════════════════════════════════════════════════════════════════════
bloco_usuarios() {
    section "👤" "Usuários do Sistema"

    # ── Usuários com shell válido (não serviços) ───────────────────────────────
    printf "  ${BOLD}${CYAN}%-15s %-6s %-20s %s${RESET}\n" \
           "Usuário" "UID" "Home" "Shell"
    sep_thin

    # Filtra usuários com UID >= 1000 (usuários reais) ou root (UID 0)
    # e que tenham shell executável (/bin/bash, /bin/sh, /bin/zsh, etc)
    while IFS=: read -r UNAME _ UID _ _ HOME SHELL; do
        # Inclui root e usuários com UID >= 1000
        if [ "$UID" -eq 0 ] || [ "$UID" -ge 1000 ] 2>/dev/null; then
            # Exclui nologin e false
            echo "$SHELL" | grep -qE "nologin|false" && continue

            # Marca usuário logado atualmente
            ONLINE=""
            who 2>/dev/null | grep -q "^${UNAME} " && ONLINE="${GREEN} ● logado${RESET}"

            # Grupos do usuário
            GRUPOS=$(id -Gn "$UNAME" 2>/dev/null | tr ' ' ',' | cut -c1-30 || echo "—")

            printf "  ${BULLET} ${BOLD}%-15s${RESET} ${DIM}%-6s${RESET} %-20s ${DIM}%s${RESET}%b\n" \
                   "$UNAME" "$UID" "$HOME" "$SHELL" "$ONLINE"
            printf "  ${DIM}  grupos: %s${RESET}\n" "$GRUPOS"
        fi
    done < /etc/passwd

    echo ""

    # ── Sessões ativas agora ───────────────────────────────────────────────────
    printf "  ${BOLD}Sessões ativas:${RESET}\n\n"
    if who 2>/dev/null | grep -q "."; then
        who 2>/dev/null | while IFS= read -r L; do
            printf "  ${BULLET} ${DIM}%s${RESET}\n" "$L"
        done
    else
        printf "  ${DIM}  Nenhuma sessão ativa além desta${RESET}\n"
    fi

    echo ""

    # ── Últimos logins ─────────────────────────────────────────────────────────
    printf "  ${BOLD}Últimos logins:${RESET}\n\n"
    last -n 5 2>/dev/null | head -5 | while IFS= read -r L; do
        printf "  ${DIM}  %s${RESET}\n" "$L"
    done
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 4 — DISCO
# Lê: df, lsblk, /proc/mounts
# ══════════════════════════════════════════════════════════════════════════════
bloco_disco() {
    section "💾" "Espaço em Disco"

    # ── Partições montadas ────────────────────────────────────────────────────
    printf "  ${BOLD}${CYAN}%-20s %-8s %-8s %-8s %s${RESET}\n" \
           "Ponto de Montagem" "Total" "Usado" "Livre" "Uso%"
    sep_thin

    # df -h lista sistemas de arquivos reais (exclui tmpfs, devtmpfs, etc)
    df -h --output=target,size,used,avail,pcent 2>/dev/null \
        | tail -n +2 \
        | grep -v "^/proc\|^/sys\|^/dev\|tmpfs\|udev" \
        | while IFS= read -r LINE; do
            MOUNT=$(echo "$LINE" | awk '{print $1}')
            SIZE=$(echo  "$LINE" | awk '{print $2}')
            USED=$(echo  "$LINE" | awk '{print $3}')
            AVAIL=$(echo "$LINE" | awk '{print $4}')
            PCT=$(echo   "$LINE" | awk '{print $5}' | tr -d '%')

            # Cor conforme uso
            if   [ "$PCT" -ge 90 ] 2>/dev/null; then COLOR="$RED"
            elif [ "$PCT" -ge 75 ] 2>/dev/null; then COLOR="$YELLOW"
            else                                      COLOR="$GREEN"
            fi

            printf "  ${BULLET} ${BOLD}%-20s${RESET} %-8s ${COLOR}%-8s${RESET} %-8s ${COLOR}%s%%${RESET}\n" \
                   "$MOUNT" "$SIZE" "$USED" "$AVAIL" "$PCT"
        done

    echo ""

    # ── Dispositivos de bloco (cartão SD, eMMC, USB) ──────────────────────────
    if command -v lsblk &>/dev/null; then
        printf "  ${BOLD}Dispositivos de bloco:${RESET}\n\n"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL 2>/dev/null \
            | while IFS= read -r L; do
                printf "  ${DIM}  %s${RESET}\n" "$L"
            done
    fi

    echo ""

    # ── Inodes (verifica se há partição com inodes esgotados) ─────────────────
    INODE_WARN=0
    df -i 2>/dev/null | tail -n +2 \
        | grep -v "^/proc\|^/sys\|tmpfs\|udev" \
        | awk '{if ($5+0 >= 90) print $0}' | while IFS= read -r L; do
            INODE_WARN=1
            step_warn "Inodes quase esgotados: $L"
        done
    [ "$INODE_WARN" -eq 0 ] 2>/dev/null && \
        printf "  ${DIM}  Inodes: sem alertas${RESET}\n"
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 5 — REDE
# Lê: ip, iw, nmcli, /etc/resolv.conf, ping
# ══════════════════════════════════════════════════════════════════════════════
bloco_rede() {
    section "🌐" "Dados de Rede"

    # ── Interfaces e IPs ──────────────────────────────────────────────────────
    printf "  ${BOLD}${CYAN}%-14s %-8s %-18s %s${RESET}\n" \
           "Interface" "Estado" "IP/Máscara" "MAC"
    sep_thin

    ip -o link show 2>/dev/null | while IFS= read -r LINE; do
        IFACE=$(echo "$LINE" | awk '{print $2}' | tr -d ':')
        [ "$IFACE" = "lo" ] && continue   # pula loopback

        STATE=$(echo "$LINE" | grep -o "state [A-Z_]*" | awk '{print $2}')
        MAC=$(echo "$LINE" | grep -o "link/ether [^ ]*" | awk '{print $2}' || echo "—")

        # IP associado à interface
        IP=$(ip -o -4 addr show "$IFACE" 2>/dev/null | awk '{print $4}' | head -1)
        IP6=$(ip -o -6 addr show "$IFACE" 2>/dev/null | awk '{print $4}' \
              | grep -v "^fe80" | head -1)
        [ -z "$IP" ] && IP="—"

        case "$STATE" in
            UP)      SC="${GREEN}UP${RESET}"      ;;
            DOWN)    SC="${RED}DOWN${RESET}"      ;;
            UNKNOWN) SC="${YELLOW}UNKN${RESET}"   ;;
            *)       SC="${DIM}${STATE}${RESET}"  ;;
        esac

        printf "  ${BULLET} ${BOLD}%-14s${RESET} %-17b %-18s ${DIM}%s${RESET}\n" \
               "$IFACE" "$SC" "$IP" "$MAC"
        [ -n "$IP6" ] && printf "  ${DIM}  %-14s          %s (IPv6)${RESET}\n" "" "$IP6"
    done

    echo ""

    # ── Gateway padrão ────────────────────────────────────────────────────────
    GW=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')
    GW_IFACE=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
    [ -z "$GW" ] && GW="—"
    row "Gateway:" "$GW  ${DIM}via ${GW_IFACE}${RESET}"

    # ── DNS ───────────────────────────────────────────────────────────────────
    DNS=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null \
          | awk '{print $2}' | tr '\n' ' ')
    [ -z "$DNS" ] && DNS="—"
    row "DNS:" "$DNS"

    echo ""

    # ── Interfaces Wi-Fi (iw) ─────────────────────────────────────────────────
    if command -v iw &>/dev/null; then
        printf "  ${BOLD}Interfaces Wi-Fi:${RESET}\n\n"
        iw dev 2>/dev/null | awk '
            /Interface/ { iface=$2; ssid="—"; mac="—"; chan="—"; freq="—" }
            /ssid/       { ssid=$2 }
            /addr/       { mac=$2 }
            /channel/    { chan=$2; freq=$4 }
            /type/       { type=$2 }
            /^}|phy#/   {
                if (iface!="") {
                    printf "    %-12s  SSID: %-20s  ch:%-4s  MAC: %s\n",
                    iface, ssid, chan, mac
                    iface=""
                }
            }
        ' | while IFS= read -r L; do
            printf "  ${BULLET} ${DIM}%s${RESET}\n" "$L"
        done
    fi

    echo ""

    # ── Teste de conectividade ─────────────────────────────────────────────────
    printf "  ${BOLD}Conectividade:${RESET}\n\n"

    # Ping para gateway
    if [ -n "$GW" ] && [ "$GW" != "—" ]; then
        ping -c1 -W2 "$GW" &>/dev/null \
            && row_status "Gateway ($GW):" "alcançável" "ok" \
            || row_status "Gateway ($GW):" "sem resposta" "err"
    fi

    # Ping para DNS público
    ping -c1 -W3 8.8.8.8 &>/dev/null \
        && row_status "Internet (8.8.8.8):" "alcançável" "ok" \
        || row_status "Internet (8.8.8.8):" "sem resposta" "err"

    # Resolução DNS
    host deb.debian.org &>/dev/null \
        && row_status "DNS (deb.debian.org):" "resolvendo" "ok" \
        || row_status "DNS (deb.debian.org):" "falhou" "warn"
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 6 — SERVIÇOS
# Lê: systemctl list-units
# Mostra: ativos, inativos e com falha — separados por categoria
# ══════════════════════════════════════════════════════════════════════════════
bloco_servicos() {
    section "⚡" "Serviços do Sistema"

    # Lista de serviços relevantes para o projeto Halfin/GhostNode
    # Dividida por categoria para melhor leitura
    declare -A CATEGORIAS
    CATEGORIAS["Rede"]="ssh NetworkManager hostapd dnsmasq dhcpcd wpa_supplicant"
    CATEGORIAS["Infraestrutura"]="docker containerd iptables netfilter-persistent cron"
    CATEGORIAS["Sistema"]="systemd-timesyncd systemd-resolved rsyslog ufw fail2ban"
    CATEGORIAS["Hardware"]="bluetooth hciuart"

    for CAT in "Rede" "Infraestrutura" "Sistema" "Hardware"; do
        echo ""
        printf "  ${BOLD}${CYAN}%s:${RESET}\n" "$CAT"
        echo ""

        for SVC in ${CATEGORIAS[$CAT]}; do
            # Verifica se o serviço existe no systemd
            if ! systemctl list-unit-files "${SVC}.service" &>/dev/null \
               || ! systemctl list-unit-files "${SVC}.service" 2>/dev/null | grep -q "$SVC"; then
                printf "  ${DIM}  %-28s não instalado${RESET}\n" "$SVC"
                continue
            fi

            STATUS=$(systemctl is-active "$SVC" 2>/dev/null || echo "unknown")
            ENABLED=$(systemctl is-enabled "$SVC" 2>/dev/null || echo "—")
            DESC=$(systemctl show -p Description --value "$SVC" 2>/dev/null \
                   | cut -c1-35 || echo "")

            case "$STATUS" in
                active)
                    printf "  ${CHECK} ${BOLD}%-28s${RESET} ${GREEN}%-10s${RESET} ${DIM}%-10s${RESET} %s\n" \
                           "$SVC" "$STATUS" "$ENABLED" "$DESC"
                    ;;
                failed)
                    printf "  ${CROSS} ${BOLD}%-28s${RESET} ${RED}%-10s${RESET} ${DIM}%-10s${RESET} %s\n" \
                           "$SVC" "$STATUS" "$ENABLED" "$DESC"
                    # Mostra últimas linhas do journal para serviços com falha
                    printf "  ${DIM}    Último erro: %s${RESET}\n" \
                           "$(journalctl -u "$SVC" -n 1 --no-pager 2>/dev/null \
                              | tail -1 | cut -c1-60 || echo "—")"
                    ;;
                inactive)
                    printf "  ${WARN}  ${BOLD}%-28s${RESET} ${YELLOW}%-10s${RESET} ${DIM}%-10s${RESET} %s\n" \
                           "$SVC" "$STATUS" "$ENABLED" "$DESC"
                    ;;
                *)
                    printf "  ${DIM}  %-28s %-10s %-10s %s${RESET}\n" \
                           "$SVC" "$STATUS" "$ENABLED" "$DESC"
                    ;;
            esac
        done
    done

    echo ""

    # ── Serviços com falha (varredura global) ─────────────────────────────────
    FAILED=$(systemctl --failed --no-legend 2>/dev/null \
             | awk '{print $1}' | grep -v "^$" || true)

    if [ -n "$FAILED" ]; then
        echo ""
        printf "  ${RED}${BOLD}Serviços com falha detectados:${RESET}\n\n"
        echo "$FAILED" | while IFS= read -r F; do
            printf "  ${CROSS} ${RED}%s${RESET}\n" "$F"
            printf "  ${DIM}    %s${RESET}\n" \
                   "$(journalctl -u "$F" -n 1 --no-pager 2>/dev/null \
                      | tail -1 | cut -c1-70 || echo "sem detalhes")"
        done
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 7 — PROCESSOS RELEVANTES
# Lê: ps aux — filtra apenas processos do projeto + alto uso
# ══════════════════════════════════════════════════════════════════════════════
bloco_processos() {
    section "📋" "Processos Relevantes"

    # ── Top 5 por CPU ─────────────────────────────────────────────────────────
    printf "  ${BOLD}Top 5 por CPU:${RESET}\n\n"
    printf "  ${BOLD}${CYAN}%-8s %-10s %6s %6s %s${RESET}\n" \
           "PID" "Usuário" "%CPU" "%MEM" "Comando"
    sep_thin

    ps aux --sort=-%cpu 2>/dev/null | tail -n +2 | head -5 \
        | while IFS= read -r LINE; do
            PID=$(echo   "$LINE" | awk '{print $2}')
            USR=$(echo   "$LINE" | awk '{print $1}')
            CPU=$(echo   "$LINE" | awk '{print $3}')
            MEM=$(echo   "$LINE" | awk '{print $4}')
            CMD=$(echo   "$LINE" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}' \
                  | cut -c1-40)

            # Realça processo com CPU alta
            CPU_INT=$(echo "$CPU" | cut -d. -f1)
            [ "$CPU_INT" -ge 50 ] 2>/dev/null \
                && COLOR="$RED" || COLOR="$WHITE"

            printf "  ${DIM}%-8s${RESET} %-10s ${COLOR}%6s${RESET} %6s ${DIM}%s${RESET}\n" \
                   "$PID" "$USR" "$CPU%" "$MEM%" "$CMD"
        done

    echo ""

    # ── Processos do projeto Halfin ───────────────────────────────────────────
    printf "  ${BOLD}Processos do projeto (halfin/ghost/docker):${RESET}\n\n"

    FOUND=0
    ps aux 2>/dev/null | grep -iE "halfin|ghostnode|hostapd|dnsmasq|docker|portainer" \
        | grep -v "grep" | while IFS= read -r LINE; do
            FOUND=1
            PID=$(echo "$LINE" | awk '{print $2}')
            USR=$(echo "$LINE" | awk '{print $1}')
            CMD=$(echo "$LINE" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}' \
                  | cut -c1-50)
            printf "  ${BULLET} ${DIM}[%s]${RESET} ${BOLD}%-10s${RESET} %s\n" "$PID" "$USR" "$CMD"
        done

    [ "$FOUND" -eq 0 ] 2>/dev/null \
        && printf "  ${DIM}  Nenhum processo específico do projeto em execução${RESET}\n"
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 8 — EQUIPAMENTOS USB/CONECTADOS
# Lê: lsusb, dmesg (USB events recentes)
# ══════════════════════════════════════════════════════════════════════════════
bloco_dispositivos() {
    section "🔌" "Equipamentos Conectados"

    if command -v lsusb &>/dev/null; then
        printf "  ${BOLD}Dispositivos USB:${RESET}\n\n"
        lsusb 2>/dev/null | while IFS= read -r L; do
            # Destaca adaptadores wireless USB
            if echo "$L" | grep -qiE "wireless|wifi|wlan|802.11|ralink|realtek|atheros|mediatek"; then
                printf "  ${CHECK} ${GREEN}%s${RESET}  ${DIM}(Wi-Fi)${RESET}\n" "$L"
            else
                printf "  ${BULLET} ${DIM}%s${RESET}\n" "$L"
            fi
        done
    else
        printf "  ${DIM}  lsusb não disponível — instale usbutils${RESET}\n"
    fi

    echo ""

    # ── Eventos USB recentes no dmesg ─────────────────────────────────────────
    printf "  ${BOLD}Eventos USB recentes (dmesg):${RESET}\n\n"
    dmesg 2>/dev/null | grep -i "usb\|mmc\|sd[a-z]" | tail -8 \
        | while IFS= read -r L; do
            printf "  ${DIM}  %s${RESET}\n" "$L"
        done || printf "  ${DIM}  Sem eventos recentes${RESET}\n"
}

# ══════════════════════════════════════════════════════════════════════════════
# BLOCO 9 — RELÓGIO EM TEMPO REAL
# Loop que atualiza a linha de data/hora/temperatura a cada segundo
# Pressione qualquer tecla para sair
# ══════════════════════════════════════════════════════════════════════════════
relogio_tempo_real() {
    echo ""
    sep
    printf "\n  ${BOLD}${CYAN}Monitoramento em tempo real${RESET}  ${DIM}(pressione qualquer tecla para sair)${RESET}\n\n"

    # Salva configurações do terminal e ativa modo não-blocante
    OLD_STTY=$(stty -g 2>/dev/null || echo "")
    stty -echo -icanon time 0 min 0 2>/dev/null || true

    while true; do
        # ── Atualiza dados em tempo real ──────────────────────────────────────

        DATETIME=$(date '+%d/%m/%Y  %H:%M:%S')
        UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "—")
        LOAD=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "—")

        # Temperatura (sysfs — mais rápido que sensors para loop)
        TEMP_RT="N/A"
        for TFILE in /sys/class/thermal/thermal_zone0/temp \
                     /sys/devices/virtual/thermal/thermal_zone0/temp; do
            [ -f "$TFILE" ] && {
                R=$(cat "$TFILE" 2>/dev/null)
                [ "$R" -gt 1000 ] 2>/dev/null \
                    && TEMP_RT="$(( R / 1000 ))°C" \
                    || TEMP_RT="${R}°C"
                break
            }
        done

        # Cor temperatura
        TEMP_NUM_RT=$(echo "$TEMP_RT" | tr -d '°C')
        if [ "$TEMP_NUM_RT" -ge 80 ] 2>/dev/null; then TC="$RED"
        elif [ "$TEMP_NUM_RT" -ge 70 ] 2>/dev/null; then TC="$YELLOW"
        else TC="$GREEN"; fi

        # Memória rápida
        MEM_T=$(awk '/^MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
        MEM_A=$(awk '/^MemAvailable/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
        MEM_U=$(( (MEM_T - MEM_A) / 1024 ))
        MEM_TM=$(( MEM_T / 1024 ))
        MEM_P=0; [ "$MEM_T" -gt 0 ] && MEM_P=$(( (MEM_T-MEM_A) * 100 / MEM_T ))

        # Cor memória
        [ "$MEM_P" -ge 90 ] 2>/dev/null && MC="$RED" \
            || { [ "$MEM_P" -ge 70 ] 2>/dev/null && MC="$YELLOW" || MC="$GREEN"; }

        # Limpa as 5 linhas anteriores e redesenha
        printf "\r\e[5A\e[J"

        printf "  ${DIM}┌────────────────────────────────────────────────────────────┐${RESET}\n"
        printf "  ${DIM}│${RESET}  ${YELLOW}🌡  Temp    :${RESET} ${TC}${BOLD}%-10s${RESET}  ${DIM}│${RESET}  ${CYAN}📅  Data/Hora :${RESET} ${BOLD}%-20s${RESET}  ${DIM}│${RESET}\n" \
               "$TEMP_RT" "$DATETIME"
        printf "  ${DIM}│${RESET}  ${GREEN}💾  Memória :${RESET} ${MC}${BOLD}%-10s${RESET}  ${DIM}│${RESET}  ${WHITE}⚡  Load      :${RESET} ${BOLD}%-20s${RESET}  ${DIM}│${RESET}\n" \
               "${MEM_U}/${MEM_TM}MB" "$LOAD"
        printf "  ${DIM}│${RESET}  ${CYAN}⏱   Uptime  :${RESET} %-32s  ${DIM}│${RESET}\n" \
               "$UPTIME"
        printf "  ${DIM}└────────────────────────────────────────────────────────────┘${RESET}\n"

        # Verifica tecla pressionada (não bloqueante)
        KEY=$(dd if=/dev/tty bs=1 count=1 2>/dev/null || echo "")
        [ -n "$KEY" ] && break

        sleep 1
    done

    # Restaura terminal
    [ -n "$OLD_STTY" ] && stty "$OLD_STTY" 2>/dev/null || true

    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# EXECUÇÃO PRINCIPAL — chama todos os blocos em sequência
# ══════════════════════════════════════════════════════════════════════════════
main() {
    clear

    # Cabeçalho
    printf "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║       System Info — Ghost Node Nation / Halfin               ║"
    printf "  ║       %-56s ║\n" "$(date '+%d/%m/%Y %H:%M:%S')"              
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    printf "${RESET}\n"

    # Executa cada bloco — cada um é independente e pode falhar sem parar os outros
    bloco_sistema      || printf "  ${WARN} Bloco Sistema falhou\n"
    bloco_hardware     || printf "  ${WARN} Bloco Hardware falhou\n"
    bloco_usuarios     || printf "  ${WARN} Bloco Usuários falhou\n"
    bloco_disco        || printf "  ${WARN} Bloco Disco falhou\n"
    bloco_rede         || printf "  ${WARN} Bloco Rede falhou\n"
    bloco_servicos     || printf "  ${WARN} Bloco Serviços falhou\n"
    bloco_processos    || printf "  ${WARN} Bloco Processos falhou\n"
    bloco_dispositivos || printf "  ${WARN} Bloco Dispositivos falhou\n"

    # Rodapé antes do relógio
    echo ""
    sep
    printf "  ${DIM}Coleta concluída — %s${RESET}\n" "$(date '+%H:%M:%S')"

    # Relógio em tempo real (loop até tecla)
    relogio_tempo_real
}

# ── Ponto de entrada ──────────────────────────────────────────────────────────
# Desativa set -e para que blocos individuais não abortem o script inteiro
set +e
main