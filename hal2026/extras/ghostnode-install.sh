#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════╗
# ║       ghostnode-install.sh — Instala o comando global        ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Uso: sudo bash ghostnode-install.sh
#

set -euo pipefail

BOLD="\e[1m"; RESET="\e[0m"; GREEN="\e[32m"
YELLOW="\e[33m"; RED="\e[31m"; CYAN="\e[36m"; DIM="\e[2m"
CHECK="${GREEN}✔${RESET}"; CROSS="${RED}✘${RESET}"; ARROW="${CYAN}▶${RESET}"

step_ok()   { printf "  ${CHECK} ${BOLD}%s${RESET}\n" "$1"; }
step_info() { printf "  ${ARROW} ${DIM}%s${RESET}\n" "$1"; }
step_err()  { printf "  ${CROSS} ${RED}%s${RESET}\n" "$1"; }

HALFIN_DIR="/home/pleb/halfin"
INSTALL_DIR="/usr/local/bin"
CMD_NAME="ghostnode"
MOTD_SCRIPT="/etc/profile.d/ghostnode-motd.sh"

clear
printf "${BOLD}${CYAN}"
echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║          ghostnode — Instalação do Comando Global            ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
printf "${RESET}\n"

# ── Verifica root ─────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    step_err "Execute como root: sudo bash ghostnode-install.sh"
    exit 1
fi

# ── Copia o binário principal ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/ghostnode"

if [ ! -f "$SRC" ]; then
    # Tenta encontrar em $HALFIN_DIR
    SRC="$HALFIN_DIR/ghostnode"
fi

if [ ! -f "$SRC" ]; then
    step_err "Arquivo 'ghostnode' não encontrado em:"
    printf "  ${DIM}  %s${RESET}\n" "$SCRIPT_DIR" "$HALFIN_DIR"
    exit 1
fi

step_info "Instalando $CMD_NAME em $INSTALL_DIR..."
cp "$SRC" "$INSTALL_DIR/$CMD_NAME"
chmod +x "$INSTALL_DIR/$CMD_NAME"
step_ok "Comando instalado: $INSTALL_DIR/$CMD_NAME"

# ── Cria MOTD — mensagem exibida no login ─────────────────────────────────────
step_info "Configurando MOTD de login..."

cat > "$MOTD_SCRIPT" << 'MOTD'
#!/bin/bash
# ghostnode MOTD — exibido em todo login de shell interativo

# Só exibe em sessões interativas
[[ $- != *i* ]] && return 0

BOLD="\e[1m"; RESET="\e[0m"; DIM="\e[2m"
GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; WHITE="\e[97m"

# Temperatura
TEMP="N/A"
for TFILE in /sys/class/thermal/thermal_zone0/temp \
             /sys/devices/virtual/thermal/thermal_zone0/temp; do
    [ -f "$TFILE" ] && TEMP="$(( $(cat "$TFILE") / 1000 ))°C" && break
done

printf "\n"
printf "${BOLD}${CYAN}"
printf "  ╔══════════════════════════════════════════════════════════════╗\n"
printf "  ║                                                              ║\n"
printf "  ║         G H O S T   N O D E S  —  H A L F I N                ║\n"
printf "  ║                                                              ║\n"
printf "  ╠══════════════════════════════════════════════════════════════╣\n"
printf "${RESET}"
printf "  ${DIM}║${RESET}  ${YELLOW}🌡  Temp   :${RESET} %-10s  ${DIM}│${RESET}  ${CYAN}📅  Data   :${RESET} %-22s  ${DIM}║${RESET}\n" \
       "$TEMP" "$(date '+%d/%m/%Y  %H:%M:%S')"
printf "  ${DIM}║${RESET}  ${WHITE}💻  Host   :${RESET} %-10s  ${DIM}│${RESET}  ${GREEN}⏱   Uptime :${RESET} %-22s  ${DIM}║${RESET}\n" \
       "$(hostname)" "$(uptime -p 2>/dev/null | sed 's/up //' | cut -c1-22)"
printf "  ${DIM}║${RESET}  ${WHITE}👤  Usuário:${RESET} %-10s  ${DIM}│${RESET}  ${CYAN}💾  Disco  :${RESET} %-22s  ${DIM}║${RESET}\n" \
       "$(whoami)" "$(df -h / 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5")"}')"
printf "${BOLD}${CYAN}"
printf "  ╠══════════════════════════════════════════════════════════════╣\n"
printf "  ║                                                              ║\n"
printf "  ║  ${RESET}${BOLD}${WHITE}Execute ${BOLD}${CYAN}ghostnode${RESET}${BOLD}${WHITE} para abrir o painel de controle.${RESET}${BOLD}${CYAN}           ║\n"
printf "  ║  ${RESET}${DIM}Use ${WHITE}ghostnode --help${RESET}${DIM} para ver todos os comandos disponíveis.${RESET}${BOLD}${CYAN}  ║\n"
printf "  ║                                                              ║\n"
printf "  ╚══════════════════════════════════════════════════════════════╝\n"
printf "${RESET}\n"
MOTD

chmod +x "$MOTD_SCRIPT"
step_ok "MOTD instalado: $MOTD_SCRIPT"

# ── Verifica se /usr/local/bin está no PATH ───────────────────────────────────
step_info "Verificando PATH..."
if echo "$PATH" | grep -q "/usr/local/bin"; then
    step_ok "/usr/local/bin está no PATH"
else
    # Adiciona ao /etc/environment se necessário
    if ! grep -q "/usr/local/bin" /etc/environment 2>/dev/null; then
        sed -i 's|PATH="|PATH="/usr/local/bin:|' /etc/environment 2>/dev/null || true
    fi
    step_ok "PATH atualizado em /etc/environment"
fi

# ── Cria link simbólico de conveniência para root ─────────────────────────────
if [ -d /root ]; then
    ln -sf "$INSTALL_DIR/$CMD_NAME" /root/ghostnode 2>/dev/null || true
fi

# ── Cria symlink em /home/pleb se existir ─────────────────────────────────────
if id pleb &>/dev/null && [ -d /home/pleb ]; then
    ln -sf "$INSTALL_DIR/$CMD_NAME" /home/pleb/ghostnode 2>/dev/null || true
    step_ok "Symlink criado em /home/pleb/ghostnode"
fi

# ── Teste rápido ──────────────────────────────────────────────────────────────
echo ""
if command -v ghostnode &>/dev/null; then
    step_ok "Comando 'ghostnode' disponível e funcional"
else
    step_ok "Comando instalado — faça logout/login ou execute: source /etc/profile"
fi

printf "\n"
printf "${BOLD}${GREEN}"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Instalação concluída!"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "${RESET}"
printf "  ${DIM}Para iniciar:${RESET}     ${BOLD}ghostnode${RESET}\n"
printf "  ${DIM}Para ajuda:${RESET}       ${BOLD}ghostnode --help${RESET}\n"
printf "  ${DIM}MOTD no login:${RESET}    ${BOLD}%s${RESET}\n" "$MOTD_SCRIPT"
printf "\n"