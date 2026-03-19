#!/bin/sh
#
# Script de instalação do Node Halfin - v0.3
# Requer execução como root: sudo sh install_halfin.sh
#
set -e

# ─── Cores ────────────────────────────────────────────────────────────────────
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
DIM="\033[2m"

# ─── Verifica root ────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    printf "${RED}[ERRO]${RESET} Execute como root: sudo %s\n" "$0"
    exit 1
fi

# ─── Cabeçalho ────────────────────────────────────────────────────────────────
clear
printf "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║        Node Halfin - Instalação v0.3                ║"
echo "  ║        Firewall / NAT / ip_forward                  ║"
echo "  ╚══════════════════════════════════════════════════════╝"
printf "${RESET}\n"

######### Detecta interface WAN ###############################################
printf "${CYAN}[*]${RESET} Detectando interface WAN...\n"

WAN_IFACE=$(ip route | awk '/^default/{print $5; exit}')
# WAN_IFACE=end0   # descomente para forçar manualmente

if [ -z "$WAN_IFACE" ]; then
    printf "${RED}[ERRO]${RESET} Interface WAN não detectada. Defina WAN_IFACE manualmente.\n"
    exit 1
fi

printf "${GREEN}[✔]${RESET} Interface WAN: ${BOLD}%s${RESET}\n\n" "$WAN_IFACE"

######### ip_forward persistente ##############################################
printf "${CYAN}[*]${RESET} Ativando ip_forward...\n"

echo 1 > /proc/sys/net/ipv4/ip_forward

if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
else
    sed -i 's/^.*net\.ipv4\.ip_forward.*$/net.ipv4.ip_forward=1/' /etc/sysctl.conf
fi
sysctl -p /etc/sysctl.conf > /dev/null

printf "${GREEN}[✔]${RESET} ip_forward ativo e persistente.\n\n"

######### Análise das regras atuais ###########################################
printf "${CYAN}[*]${RESET} Analisando regras iptables existentes...\n\n"

# ── Regras que o Halfin precisa (referência) ──────────────────────────────────
NEED_FWD_IN="-A FORWARD -i ${WAN_IFACE} -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT"
NEED_FWD_OUT="-A FORWARD -i br0 -o ${WAN_IFACE} -j ACCEPT"
NEED_NAT="-A POSTROUTING -o ${WAN_IFACE} -j MASQUERADE"

# ── Captura estado atual ──────────────────────────────────────────────────────
CURRENT_FILTER=$(iptables-save -t filter 2>/dev/null)
CURRENT_NAT=$(iptables-save -t nat 2>/dev/null)

printf "  ${DIM}%-55s  %s${RESET}\n" "Regra necessária" "Status"
printf "  ${DIM}%-55s  %s${RESET}\n" \
    "───────────────────────────────────────────────────────" "──────────"

# ── Verifica cada regra necessária ───────────────────────────────────────────
FWD_IN_EXISTS=0
FWD_OUT_EXISTS=0
NAT_EXISTS=0

if echo "$CURRENT_FILTER" | grep -qF "$NEED_FWD_IN"; then
    printf "  %-55s ${GREEN}já existe${RESET}\n" "FORWARD ${WAN_IFACE}→br0 ESTABLISHED"
    FWD_IN_EXISTS=1
else
    printf "  %-55s ${YELLOW}ausente${RESET}\n"  "FORWARD ${WAN_IFACE}→br0 ESTABLISHED"
fi

if echo "$CURRENT_FILTER" | grep -qF "$NEED_FWD_OUT"; then
    printf "  %-55s ${GREEN}já existe${RESET}\n" "FORWARD br0→${WAN_IFACE} ACCEPT"
    FWD_OUT_EXISTS=1
else
    printf "  %-55s ${YELLOW}ausente${RESET}\n"  "FORWARD br0→${WAN_IFACE} ACCEPT"
fi

if echo "$CURRENT_NAT" | grep -qF "$NEED_NAT"; then
    printf "  %-55s ${GREEN}já existe${RESET}\n" "NAT POSTROUTING ${WAN_IFACE} MASQUERADE"
    NAT_EXISTS=1
else
    printf "  %-55s ${YELLOW}ausente${RESET}\n"  "NAT POSTROUTING ${WAN_IFACE} MASQUERADE"
fi

echo ""

######### Detecta e remove conflitos ##########################################
printf "${CYAN}[*]${RESET} Verificando regras conflitantes...\n\n"

CONFLICTS=0

# ── Conflito 1: FORWARD DROP/REJECT envolvendo WAN_IFACE ou br0 ──────────────
NUMS=$(iptables -L FORWARD --line-numbers -n 2>/dev/null \
    | awk -v wan="$WAN_IFACE" '
        /DROP|REJECT/ {
            if ($0 ~ wan || $0 ~ "br0") print $1
        }' | sort -rn)

if [ -n "$NUMS" ]; then
    printf "  ${YELLOW}⚠  FORWARD bloqueante (DROP/REJECT) em %s ou br0:${RESET}\n" "$WAN_IFACE"
    for NUM in $NUMS; do
        LINE=$(iptables -L FORWARD --line-numbers -n | awk -v n="$NUM" '$1==n{print}')
        printf "     ${RED}Linha #%s: %s${RESET}\n" "$NUM" "$LINE"
        iptables -D FORWARD "$NUM" 2>/dev/null
        printf "  ${RED}[✘]${RESET} Removida FORWARD #%s\n" "$NUM"
        CONFLICTS=$((CONFLICTS + 1))
    done
    echo ""
fi

# ── Conflito 2: MASQUERADE em interface diferente da WAN (double-NAT) ─────────
DUP_NUMS=$(iptables -t nat -L POSTROUTING --line-numbers -n 2>/dev/null \
    | awk -v wan="$WAN_IFACE" '
        /MASQUERADE/ && $0 !~ wan { print $1 }' | sort -rn)

if [ -n "$DUP_NUMS" ]; then
    printf "  ${YELLOW}⚠  MASQUERADE em interface diferente de %s (possível double-NAT):${RESET}\n" "$WAN_IFACE"
    for NUM in $DUP_NUMS; do
        LINE=$(iptables -t nat -L POSTROUTING --line-numbers -n | awk -v n="$NUM" '$1==n{print}')
        printf "     ${RED}Linha #%s: %s${RESET}\n" "$NUM" "$LINE"
        iptables -t nat -D POSTROUTING "$NUM" 2>/dev/null
        printf "  ${RED}[✘]${RESET} Removida NAT POSTROUTING #%s (MASQUERADE conflitante)\n" "$NUM"
        CONFLICTS=$((CONFLICTS + 1))
    done
    echo ""
fi

# ── Conflito 3: MASQUERADE duplicado na mesma WAN_IFACE ───────────────────────
MASQ_COUNT=$(iptables -t nat -L POSTROUTING -n 2>/dev/null \
    | grep -c "MASQUERADE" || true)

if [ "$MASQ_COUNT" -gt 1 ]; then
    printf "  ${YELLOW}⚠  %s entradas MASQUERADE duplicadas na WAN — limpando POSTROUTING...${RESET}\n" "$MASQ_COUNT"
    iptables -t nat -F POSTROUTING
    NAT_EXISTS=0
    printf "  ${RED}[✘]${RESET} NAT POSTROUTING limpo (duplicatas removidas)\n\n"
    CONFLICTS=$((CONFLICTS + 1))
fi

if [ "$CONFLICTS" -eq 0 ]; then
    printf "  ${GREEN}[✔]${RESET} Nenhum conflito encontrado.\n\n"
fi

######### Aplica apenas as regras ausentes ####################################
printf "${CYAN}[*]${RESET} Aplicando regras ausentes...\n\n"

ADDED=0

if [ "$FWD_IN_EXISTS" -eq 0 ]; then
    iptables -A FORWARD -i "$WAN_IFACE" -o br0 \
        -m state --state RELATED,ESTABLISHED -j ACCEPT
    printf "  ${GREEN}[+]${RESET} FORWARD %s→br0 ESTABLISHED adicionada\n" "$WAN_IFACE"
    ADDED=$((ADDED + 1))
fi

if [ "$FWD_OUT_EXISTS" -eq 0 ]; then
    iptables -A FORWARD -i br0 -o "$WAN_IFACE" -j ACCEPT
    printf "  ${GREEN}[+]${RESET} FORWARD br0→%s ACCEPT adicionada\n" "$WAN_IFACE"
    ADDED=$((ADDED + 1))
fi

if [ "$NAT_EXISTS" -eq 0 ]; then
    iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
    printf "  ${GREEN}[+]${RESET} NAT POSTROUTING %s MASQUERADE adicionada\n" "$WAN_IFACE"
    ADDED=$((ADDED + 1))
fi

if [ "$ADDED" -eq 0 ]; then
    printf "  ${GREEN}[✔]${RESET} Todas as regras já estavam presentes. Nada adicionado.\n"
fi

echo ""

######### Persistência ########################################################
printf "${CYAN}[*]${RESET} Salvando regras...\n"

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

RESTORE_SCRIPT="/etc/network/if-up.d/iptables-halfin"
cat > "$RESTORE_SCRIPT" <<'SCRIPT'
#!/bin/sh
# Restaura regras iptables do Halfin ao subir interface
if [ -f /etc/iptables/rules.v4 ]; then
    iptables-restore < /etc/iptables/rules.v4
fi
SCRIPT
chmod +x "$RESTORE_SCRIPT"

printf "${GREEN}[✔]${RESET} Regras salvas em /etc/iptables/rules.v4\n"
printf "${GREEN}[✔]${RESET} Script de boot: %s\n\n" "$RESTORE_SCRIPT"

######### Resumo final ########################################################
printf "${BOLD}${CYAN}"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Resultado Final"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "${RESET}"
printf "  WAN Interface  : ${BOLD}%s${RESET}\n"   "$WAN_IFACE"
printf "  ip_forward     : ${BOLD}%s${RESET}\n"   "$(cat /proc/sys/net/ipv4/ip_forward)"
printf "  Conflitos rem. : ${BOLD}%s${RESET}\n"   "$CONFLICTS"
printf "  Regras adicion.: ${BOLD}%s${RESET}\n\n" "$ADDED"

printf "  ${BOLD}FORWARD ativo:${RESET}\n"
iptables -L FORWARD --line-numbers -n 2>/dev/null | sed 's/^/    /'
echo ""
printf "  ${BOLD}NAT POSTROUTING ativo:${RESET}\n"
iptables -t nat -L POSTROUTING --line-numbers -n 2>/dev/null | sed 's/^/    /'
echo ""
