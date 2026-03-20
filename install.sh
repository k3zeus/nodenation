#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════╗
# ║       Halfin Install — Ghost Node Nation  v0.4               ║
# ║       20/03/2026                                             ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Uso direto : sudo bash install.sh
# Via curl   : curl -fsSL https://<url>/install.sh | sudo bash
#
# Etapas:
#   1. Verificação de hardware e usuário (OrangePi Zero 3 / Debian arm64)
#   2. Criação do usuário pleb + sources.list + hostname
#   3. Atualização do sistema e instalação de ferramentas
#   4. Download e preparação do projeto Ghost Nodes
#   5. Remoção do usuário orangepi
#

# ══════════════════════════════════════════════════════════════════════════════
# BOOTSTRAP — detecta execução via pipe (curl | bash) e se re-executa com TTY
# ══════════════════════════════════════════════════════════════════════════════
# Quando stdin NÃO é um TTY, estamos sendo lidos via pipe do curl.
# Salvamos o script em disco e reiniciamos vinculando stdin ao terminal real,
# para que read/menus funcionem normalmente.
SELFPATH="/tmp/halfin_install.sh"

if [ ! -t 0 ]; then
    cat > "$SELFPATH"
    chmod +x "$SELFPATH"

    if [ "$EUID" -ne 0 ]; then
        echo ""
        echo "  [ERRO] Execute como root: curl -fsSL <url>/install.sh | sudo bash"
        echo ""
        rm -f "$SELFPATH"
        exit 1
    fi

    # Re-executa com TTY real como stdin
    exec bash "$SELFPATH" < /dev/tty
fi

set -euo pipefail

# ─── Cores e símbolos ─────────────────────────────────────────────────────────
BOLD="\e[1m"
RESET="\e[0m"
DIM="\e[2m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
MAGENTA="\e[35m"
WHITE="\e[97m"
BG_DARK="\e[40m"
CHECK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
ARROW="${CYAN}▶${RESET}"
WARN="${YELLOW}⚠${RESET}"

# ─── Arquivo de estado (persiste entre execuções) ─────────────────────────────
STATE_FILE="/var/lib/halfin_install.state"

# ─── Funções de UI ────────────────────────────────────────────────────────────

header() {
    clear
    printf "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║                                                              ║"
    echo "  ║          ░██████╗░██╗░░██╗░█████╗░░██████╗████████╗          ║"
    echo "  ║          ██╔════╝░██║░░██║██╔══██╗██╔════╝╚══██╔══╝          ║"
    echo "  ║          ██║░░██╗░███████║██║░░██║╚█████╗░░░░██║░░           ║"
    echo "  ║          ██║░░╚██╗██╔══██║██║░░██║░╚═══██╗░░░██║░░           ║"
    echo "  ║          ╚██████╔╝██║░░██║╚█████╔╝██████╔╝░░░██║░░           ║"
    echo "  ║           ╚═════╝ ╚═╝  ╚═╝ ╚════╝ ╚═════╝    ╚═╝             ║"
    echo "  ║                                                              ║"
    echo "  ║              Ghost Node Nation  —  Install v0.3              ║"
    echo "  ║                    OrangePi Zero 3 / Debian                  ║"
    echo "  ║                                                              ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    printf "${RESET}\n"
}

section() {
    echo ""
    printf "${BOLD}${MAGENTA}  ┌─ %s ${DIM}%s${RESET}\n" "$1" "────────────────────────────────────────────"
    printf "${RESET}"
}

step_ok()   { printf "  ${CHECK} ${WHITE}%s${RESET}\n" "$1"; }
step_warn() { printf "  ${WARN}  ${YELLOW}%s${RESET}\n" "$1"; }
step_err()  { printf "  ${CROSS} ${RED}%s${RESET}\n" "$1"; }
step_info() { printf "  ${ARROW} ${DIM}%s${RESET}\n" "$1"; }

sep() {
    printf "${DIM}  ────────────────────────────────────────────────────────────${RESET}\n"
}

press_enter() {
    echo ""
    printf "  ${DIM}Pressione ENTER para continuar...${RESET}"
    read -r
}

confirm() {
    local MSG="$1"
    local DEFAULT="${2:-s}"
    if [ "$DEFAULT" = "s" ]; then
        local OPTS="${GREEN}S${RESET}/${DIM}n${RESET}"
    else
        local OPTS="${DIM}s${RESET}/${GREEN}N${RESET}"
    fi
    printf "\n  ${YELLOW}?${RESET} %s [%b]: " "$MSG" "$OPTS"
    read -r REPLY
    REPLY="${REPLY:-$DEFAULT}"
    [[ "$REPLY" =~ ^[sS]$ ]]
}

spinner() {
    local PID=$1
    local MSG="$2"
    local FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$PID" 2>/dev/null; do
        printf "\r  ${CYAN}%s${RESET}  %s " "${FRAMES[$((i % 10))]}" "$MSG"
        sleep 0.1
        i=$((i + 1))
    done
    printf "\r  ${CHECK}  %-55s\n" "$MSG"
}

# ─── Estado de instalação ─────────────────────────────────────────────────────

state_get() {
    grep -m1 "^${1}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "0"
}

state_set() {
    if grep -q "^${1}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s/^${1}=.*/${1}=${2}/" "$STATE_FILE"
    else
        echo "${1}=${2}" >> "$STATE_FILE"
    fi
}

init_state() {
    [ -f "$STATE_FILE" ] || touch "$STATE_FILE"
}

# ─── Verificação root ─────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo ""
    printf "  ${RED}[ERRO]${RESET} Este script precisa ser executado como root.\n"
    printf "         Arquivo local : ${BOLD}sudo bash %s${RESET}\n" "$SELFPATH"
    printf "         Via curl      : ${BOLD}curl -fsSL <url>/install.sh | sudo bash${RESET}\n\n"
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════

show_menu() {
    header

    # Status de cada etapa
    S1=$(state_get "etapa1"); S2=$(state_get "etapa2")
    S3=$(state_get "etapa3"); S4=$(state_get "etapa4")
    S5=$(state_get "etapa5")

    badge() {
        if   [ "$1" = "1" ]; then printf "${GREEN}${BOLD}[✔ concluída]${RESET}"
        elif [ "$1" = "2" ]; then printf "${YELLOW}[⟳ parcial]${RESET}"
        else                       printf "${DIM}[pendente]${RESET}"
        fi
    }

    echo ""
    printf "  ${BOLD}${WHITE}Progresso da Instalação:${RESET}\n\n"
    printf "  ${BOLD}[1]${RESET}  Verificação de Hardware e Sistema        %b\n" "$(badge $S1)"
    printf "  ${BOLD}[2]${RESET}  Usuário pleb + Sources + Hostname        %b\n" "$(badge $S2)"
    printf "  ${BOLD}[3]${RESET}  Atualização + Ferramentas                %b\n" "$(badge $S3)"
    printf "  ${BOLD}[4]${RESET}  Download e Preparação do Projeto         %b\n" "$(badge $S4)"
    printf "  ${BOLD}[5]${RESET}  Remoção do usuário orangepi              %b\n" "$(badge $S5)"
    echo ""
    sep
    printf "  ${BOLD}[a]${RESET}  Executar todas as etapas em sequência\n"
    printf "  ${BOLD}[s]${RESET}  Status detalhado\n"
    printf "  ${BOLD}[q]${RESET}  Sair\n"
    sep
    echo ""
    printf "  Escolha uma opção: "
    read -r OPT

    case "$OPT" in
        1) etapa1 ;;
        2) etapa2 ;;
        3) etapa3 ;;
        4) etapa4 ;;
        5) etapa5 ;;
        a|A) run_all ;;
        s|S) show_status ;;
        q|Q) printf "\n  ${DIM}Saindo...${RESET}\n\n"; exit 0 ;;
        *) printf "\n  ${RED}Opção inválida.${RESET}\n"; sleep 1; show_menu ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# STATUS DETALHADO
# ══════════════════════════════════════════════════════════════════════════════

show_status() {
    header
    section "Status do Sistema"
    echo ""

    # Hardware
    ARCH=$(uname -m)
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "desconhecido")
    HOSTNAME_CUR=$(hostname)
    OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "desconhecido")
    KERNEL=$(uname -r)

    printf "  ${DIM}Modelo      :${RESET} ${BOLD}%s${RESET}\n" "$MODEL"
    printf "  ${DIM}Arquitetura :${RESET} ${BOLD}%s${RESET}\n" "$ARCH"
    printf "  ${DIM}SO          :${RESET} ${BOLD}%s${RESET}\n" "$OS"
    printf "  ${DIM}Kernel      :${RESET} ${BOLD}%s${RESET}\n" "$KERNEL"
    printf "  ${DIM}Hostname    :${RESET} ${BOLD}%s${RESET}\n" "$HOSTNAME_CUR"
    echo ""

    # Usuários
    id orangepi &>/dev/null \
        && printf "  ${DIM}Usuário orangepi :${RESET} ${YELLOW}existe${RESET}\n" \
        || printf "  ${DIM}Usuário orangepi :${RESET} ${DIM}removido${RESET}\n"

    id pleb &>/dev/null \
        && printf "  ${DIM}Usuário pleb     :${RESET} ${GREEN}existe${RESET}\n" \
        || printf "  ${DIM}Usuário pleb     :${RESET} ${RED}não criado${RESET}\n"
    echo ""

    # Etapas
    section "Etapas de Instalação"
    echo ""
    for i in 1 2 3 4 5; do
        S=$(state_get "etapa${i}")
        LABELS=("" \
            "Verificação de Hardware" \
            "Usuário pleb + Sources + Hostname" \
            "Atualização + Ferramentas" \
            "Download e Preparação do Projeto" \
            "Remoção do usuário orangepi")
        if   [ "$S" = "1" ]; then printf "  ${CHECK} Etapa %s: ${GREEN}%s${RESET}\n" "$i" "${LABELS[$i]}"
        else                       printf "  ${CROSS} Etapa %s: ${DIM}%s (pendente)${RESET}\n" "$i" "${LABELS[$i]}"
        fi
    done

    press_enter
    show_menu
}

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 1 — Verificação de Hardware e Sistema
# ══════════════════════════════════════════════════════════════════════════════

etapa1() {
    header
    section "Etapa 1 — Verificação de Hardware e Sistema"
    echo ""

    ERROS=0

    # ── Arquitetura arm64 ─────────────────────────────────────────────────────
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        step_ok "Arquitetura: ${BOLD}arm64 (aarch64)${RESET}"
    else
        step_err "Arquitetura detectada: ${BOLD}${ARCH}${RESET} — esperado arm64"
        ERROS=$((ERROS + 1))
    fi

    # ── Debian Bookworm ───────────────────────────────────────────────────────
    if grep -qi "bookworm" /etc/os-release 2>/dev/null; then
        OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        step_ok "Sistema: ${BOLD}${OS}${RESET}"
    else
        step_err "Sistema não é Debian Bookworm"
        ERROS=$((ERROS + 1))
    fi

    # ── Modelo OrangePi Zero 3 ────────────────────────────────────────────────
    MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "")
    if echo "$MODEL" | grep -qi "orange pi zero 3\|orangepi zero3"; then
        step_ok "Hardware: ${BOLD}${MODEL}${RESET}"
    else
        if [ -z "$MODEL" ]; then
            step_warn "Modelo de hardware não detectado via device-tree"
        else
            step_warn "Hardware detectado: ${BOLD}${MODEL}${RESET}"
            step_warn "Esperado: OrangePi Zero 3 — verifique compatibilidade"
        fi
        echo ""
        if ! confirm "Continuar mesmo assim?"; then
            step_err "Instalação abortada pelo usuário."
            press_enter
            show_menu
            return
        fi
    fi

    # ── Usuário orangepi ──────────────────────────────────────────────────────
    if id orangepi &>/dev/null; then
        step_ok "Usuário ${BOLD}orangepi${RESET} encontrado"
    else
        step_warn "Usuário ${BOLD}orangepi${RESET} não existe (pode já ter sido removido)"
    fi

    # ── Usuário pleb ──────────────────────────────────────────────────────────
    if id pleb &>/dev/null; then
        step_ok "Usuário ${BOLD}pleb${RESET} já existe"
    else
        step_info "Usuário ${BOLD}pleb${RESET} ainda não criado — será criado na etapa 2"
    fi

    echo ""
    if [ "$ERROS" -gt 0 ]; then
        sep
        step_err "${ERROS} verificação(ões) falharam."
        if ! confirm "Forçar continuação mesmo com erros?"; then
            press_enter
            show_menu
            return
        fi
    fi

    state_set "etapa1" "1"
    step_ok "${BOLD}Etapa 1 concluída.${RESET}"
    press_enter
    show_menu
}

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 2 — Usuário pleb + Sources.list + Hostname
# ══════════════════════════════════════════════════════════════════════════════

etapa2() {
    header
    section "Etapa 2 — Usuário pleb + Sources.list + Hostname"

    if [ "$(state_get etapa1)" != "1" ]; then
        echo ""
        step_warn "Etapa 1 não foi concluída."
        if ! confirm "Executar etapa 1 antes de continuar?"; then
            show_menu; return
        fi
        etapa1
        return
    fi

    echo ""

    # ── Criação do usuário pleb ───────────────────────────────────────────────
    if id pleb &>/dev/null; then
        step_ok "Usuário ${BOLD}pleb${RESET} já existe — pulando criação"
    else
        step_info "Criando usuário ${BOLD}pleb${RESET}..."
        adduser --disabled-password --gecos "" pleb
        echo "pleb:Mudar123" | chpasswd
        usermod -aG sudo pleb
        step_ok "Usuário ${BOLD}pleb${RESET} criado. Senha padrão: ${YELLOW}Mudar123${RESET} ${RED}(altere após o login!)${RESET}"
    fi

    # ── Hostname ──────────────────────────────────────────────────────────────
    CUR_HOST=$(hostname)
    if [ "$CUR_HOST" = "halfin" ]; then
        step_ok "Hostname já configurado: ${BOLD}halfin${RESET}"
    else
        step_info "Configurando hostname para ${BOLD}halfin${RESET} (atual: ${CUR_HOST})..."
        echo "halfin" > /etc/hostname
        hostname halfin
        # Atualiza /etc/hosts se necessário
        if ! grep -q "halfin" /etc/hosts; then
            sed -i "s/127.0.1.1.*/127.0.1.1\thalfin/" /etc/hosts 2>/dev/null \
                || echo "127.0.1.1	halfin" >> /etc/hosts
        fi
        step_ok "Hostname definido: ${BOLD}halfin${RESET}"
    fi

    # ── Sources.list ──────────────────────────────────────────────────────────
    SOURCES_OK=0
    if grep -q "deb.debian.org/debian bookworm" /etc/apt/sources.list 2>/dev/null \
        && ! grep -qi "ubuntu\|armbian\|orangepi" /etc/apt/sources.list 2>/dev/null; then
        step_ok "sources.list já está configurado com repositórios Debian oficiais"
        SOURCES_OK=1
    fi

    if [ "$SOURCES_OK" -eq 0 ]; then
        step_info "Configurando sources.list com repositórios Debian Bookworm oficiais..."
        # Backup do sources.list atual
        cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
        cat > /etc/apt/sources.list <<'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
#deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES
        step_ok "sources.list atualizado"
    fi

    # ── Remove lista Docker se existir ────────────────────────────────────────
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        step_info "Removendo /etc/apt/sources.list.d/docker.list..."
        rm -f /etc/apt/sources.list.d/docker.list
        step_ok "Lista Docker removida"
    else
        step_info "docker.list não encontrado — nada a remover"
    fi

    # ── Remove pacotes Docker conflitantes ────────────────────────────────────
    DOCKER_PKGS="docker.io docker-doc docker-compose podman-docker containerd runc"
    INSTALLED_DOCKER=""
    for pkg in $DOCKER_PKGS; do
        dpkg -l "$pkg" &>/dev/null && INSTALLED_DOCKER="$INSTALLED_DOCKER $pkg" || true
    done

    if [ -n "$INSTALLED_DOCKER" ]; then
        step_warn "Pacotes Docker encontrados:${YELLOW}${INSTALLED_DOCKER}${RESET}"
        if confirm "Remover pacotes Docker conflitantes?"; then
            apt-get remove -y $INSTALLED_DOCKER 2>/dev/null || true
            step_ok "Pacotes Docker removidos"
        fi
    else
        step_info "Nenhum pacote Docker conflitante encontrado"
    fi

    echo ""
    state_set "etapa2" "1"
    step_ok "${BOLD}Etapa 2 concluída.${RESET}"
    press_enter
    show_menu
}

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 3 — Atualização do sistema + Instalação de ferramentas
# ══════════════════════════════════════════════════════════════════════════════

etapa3() {
    header
    section "Etapa 3 — Atualização do Sistema e Ferramentas"

    if [ "$(state_get etapa2)" != "1" ]; then
        echo ""
        step_warn "Etapa 2 não foi concluída."
        if ! confirm "Executar etapa 2 antes de continuar?"; then
            show_menu; return
        fi
        etapa2
        return
    fi

    echo ""

    PKGS="git htop vim net-tools nmap tree lm-sensors dos2unix openssh-server \
          iptraf-ng hostapd iptables iw traceroute bridge-utils iptables-persistent \
          btop sqlite3 ca-certificates curl gnupg lsb-release"

    # ── apt update ────────────────────────────────────────────────────────────
    step_info "Atualizando lista de pacotes (apt update)..."
    echo ""
    apt-get update 2>&1 | while IFS= read -r line; do
        printf "  ${DIM}%s${RESET}\n" "$line"
    done
    step_ok "Lista de pacotes atualizada"
    echo ""

    # ── apt upgrade ───────────────────────────────────────────────────────────
    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || true)
    if [ "$UPGRADABLE" -gt 0 ]; then
        step_info "${UPGRADABLE} pacote(s) com atualização disponível"
        if confirm "Executar upgrade completo do sistema? (recomendado)"; then
            echo ""
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | while IFS= read -r line; do
                printf "  ${DIM}%s${RESET}\n" "$line"
            done
            step_ok "Sistema atualizado"
        fi
    else
        step_ok "Sistema já está atualizado"
    fi

    echo ""

    # ── Verifica quais pacotes faltam ─────────────────────────────────────────
    step_info "Verificando pacotes necessários..."
    MISSING=""
    for pkg in $PKGS; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            MISSING="$MISSING $pkg"
        fi
    done

    if [ -z "$MISSING" ]; then
        step_ok "Todos os pacotes já estão instalados"
    else
        echo ""
        step_warn "Pacotes a instalar:${YELLOW}${MISSING}${RESET}"
        echo ""
        if confirm "Instalar os pacotes ausentes?"; then
            echo ""
            DEBIAN_FRONTEND=noninteractive apt-get install -y $MISSING 2>&1 | while IFS= read -r line; do
                printf "  ${DIM}%s${RESET}\n" "$line"
            done
            echo ""
            step_ok "Ferramentas instaladas"
        else
            step_warn "Instalação de pacotes pulada — pode causar falhas nas etapas seguintes"
        fi
    fi

    echo ""
    state_set "etapa3" "1"
    step_ok "${BOLD}Etapa 3 concluída.${RESET}"
    press_enter
    show_menu
}

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 4 — Download e Preparação do Projeto Ghost Nodes
# ══════════════════════════════════════════════════════════════════════════════

etapa4() {
    header
    section "Etapa 4 — Download e Preparação do Projeto"

    if [ "$(state_get etapa3)" != "1" ]; then
        echo ""
        step_warn "Etapa 3 não foi concluída."
        if ! confirm "Executar etapa 3 antes de continuar?"; then
            show_menu; return
        fi
        etapa3
        return
    fi

    echo ""

    PLEB_HOME="/home/pleb"
    TARBALL="${PLEB_HOME}/beta_v2.tar.gz"
    EXTRACT_DIR="${PLEB_HOME}/nodenation-beta_v2"
    HALFIN_DIR="${PLEB_HOME}/halfin"
    SATOSHI_DIR="${PLEB_HOME}/satoshi"
    REPO_URL="https://github.com/k3zeus/nodenation/archive/refs/tags/beta_v2.tar.gz"

    # ── Verifica diretórios já extraídos ──────────────────────────────────────
    HALFIN_OK=0; SATOSHI_OK=0

    [ -d "$HALFIN_DIR" ]  && HALFIN_OK=1
    [ -d "$SATOSHI_DIR" ] && SATOSHI_OK=1

    if [ "$HALFIN_OK" -eq 1 ] && [ "$SATOSHI_OK" -eq 1 ]; then
        step_ok "Diretórios ${BOLD}halfin${RESET} e ${BOLD}satoshi${RESET} já existem"
        if ! confirm "Reextrair e reconfigurar mesmo assim?"; then
            state_set "etapa4" "1"
            etapa4_scripts
            return
        fi
    fi

    # ── Download ──────────────────────────────────────────────────────────────
    if [ -f "$TARBALL" ]; then
        step_ok "Arquivo já baixado: ${BOLD}${TARBALL}${RESET}"
        if ! confirm "Baixar novamente?"; then
            : # mantém o tarball existente
        else
            rm -f "$TARBALL"
        fi
    fi

    if [ ! -f "$TARBALL" ]; then
        step_info "Baixando projeto de ${CYAN}${REPO_URL}${RESET}..."
        echo ""
        if wget -q --show-progress -O "$TARBALL" "$REPO_URL"; then
            step_ok "Download concluído: ${BOLD}$(du -sh "$TARBALL" | cut -f1)${RESET}"
        else
            step_err "Falha no download. Verifique conectividade e a URL."
            press_enter
            show_menu
            return
        fi
    fi

    echo ""

    # ── Extração ──────────────────────────────────────────────────────────────
    step_info "Extraindo arquivos..."
    rm -rf "$EXTRACT_DIR"
    tar -xzf "$TARBALL" -C "$PLEB_HOME" 2>&1 | while IFS= read -r line; do
        printf "  ${DIM}%s${RESET}\n" "$line"
    done

    if [ ! -d "$EXTRACT_DIR" ]; then
        step_err "Extração falhou — diretório ${EXTRACT_DIR} não encontrado"
        step_info "Conteúdo de ${PLEB_HOME}:"
        ls "$PLEB_HOME" | sed 's/^/    /'
        press_enter
        show_menu
        return
    fi
    step_ok "Arquivos extraídos em ${BOLD}${EXTRACT_DIR}${RESET}"
    echo ""

    # ── Move pastas ───────────────────────────────────────────────────────────
    # halfin (originalmente hal2026)
    if [ -d "${EXTRACT_DIR}/hal2026" ]; then
        rm -rf "$HALFIN_DIR"
        mv "${EXTRACT_DIR}/hal2026" "$HALFIN_DIR"
        step_ok "Pasta ${BOLD}hal2026${RESET} → ${BOLD}halfin${RESET}"
    elif [ -d "${EXTRACT_DIR}/halfin" ]; then
        rm -rf "$HALFIN_DIR"
        mv "${EXTRACT_DIR}/halfin" "$HALFIN_DIR"
        step_ok "Pasta ${BOLD}halfin${RESET} movida"
    else
        step_warn "Pasta hal2026/halfin não encontrada no tarball — verifique estrutura"
        ls "$EXTRACT_DIR" | sed 's/^/    /'
    fi

    # satoshi
    if [ -d "${EXTRACT_DIR}/satoshi" ]; then
        rm -rf "$SATOSHI_DIR"
        mv "${EXTRACT_DIR}/satoshi" "$SATOSHI_DIR"
        step_ok "Pasta ${BOLD}satoshi${RESET} movida"
    else
        step_warn "Pasta satoshi não encontrada no tarball"
    fi

    echo ""

    # ── Converte line endings ──────────────────────────────────────────────────
    step_info "Convertendo line endings (dos2unix)..."
    find "$PLEB_HOME" -type f -name "*.sh" -print0 | xargs -0 dos2unix -q 2>/dev/null || true
    step_ok "Line endings convertidos"

    # ── Permissões ────────────────────────────────────────────────────────────
    step_info "Ajustando permissões dos scripts..."
    find "$PLEB_HOME" -name "*.sh" -type f -print0 | xargs -0 chmod +x 2>/dev/null || true
    chown -R pleb:pleb "$PLEB_HOME" 2>/dev/null || true
    step_ok "Permissões ajustadas"

    echo ""
    rm -rf "$EXTRACT_DIR"

    # ── script_orange3.sh ─────────────────────────────────────────────────────
    etapa4_scripts
}

etapa4_scripts() {
    HALFIN_DIR="/home/pleb/halfin"
    ORANGE_SCRIPT="${HALFIN_DIR}/script_orange3.sh"

    section "Etapa 4.1 — script_orange3.sh"
    echo ""

    if [ ! -f "$ORANGE_SCRIPT" ]; then
        step_warn "script_orange3.sh não encontrado em ${HALFIN_DIR}"
        step_info "Conteúdo de ${HALFIN_DIR}:"
        ls "$HALFIN_DIR" 2>/dev/null | sed 's/^/    /' || echo "    (vazio ou inexistente)"
        echo ""
        if ! confirm "Pular e continuar mesmo assim?"; then
            press_enter; show_menu; return
        fi
    else
        step_ok "Script encontrado: ${BOLD}${ORANGE_SCRIPT}${RESET}"
        echo ""
        if confirm "Executar ${BOLD}script_orange3.sh${RESET} agora?"; then
            echo ""
            sep
            cd "$HALFIN_DIR"
            bash ./script_orange3.sh || {
                step_err "script_orange3.sh retornou erro"
                if ! confirm "Continuar mesmo com erro?"; then
                    press_enter; show_menu; return
                fi
            }
            sep
            echo ""
            step_ok "script_orange3.sh finalizado"
        else
            step_warn "Execução do script_orange3.sh pulada"
        fi
    fi

    state_set "etapa4" "1"
    step_ok "${BOLD}Etapa 4 concluída.${RESET}"
    press_enter
    show_menu
}

# ══════════════════════════════════════════════════════════════════════════════
# ETAPA 5 — Remoção do usuário orangepi
# ══════════════════════════════════════════════════════════════════════════════

etapa5() {
    header
    section "Etapa 5 — Remoção do usuário orangepi"

    if [ "$(state_get etapa4)" != "1" ]; then
        echo ""
        step_warn "Etapa 4 não foi concluída."
        if ! confirm "Pular verificação e continuar mesmo assim?"; then
            show_menu; return
        fi
    fi

    echo ""

    if ! id orangepi &>/dev/null; then
        step_ok "Usuário ${BOLD}orangepi${RESET} já não existe — nada a fazer"
        state_set "etapa5" "1"
        press_enter
        show_menu
        return
    fi

    step_info "Iniciando remoção do usuário orangepi..."
    echo ""

    # ── Remove override de autologin ──────────────────────────────────────────
    GETTY_OVERRIDE="/lib/systemd/system/getty@.service.d/override.conf"
    SERIAL_OVERRIDE="/lib/systemd/system/serial-getty@.service.d/override.conf"

    if [ -f "$GETTY_OVERRIDE" ]; then
        rm -f "$GETTY_OVERRIDE"
        step_ok "Removido: ${BOLD}${GETTY_OVERRIDE}${RESET}"
    else
        step_info "Getty override não encontrado — nada a remover"
    fi

    if [ -f "$SERIAL_OVERRIDE" ]; then
        rm -f "$SERIAL_OVERRIDE"
        step_ok "Removido: ${BOLD}${SERIAL_OVERRIDE}${RESET}"
    else
        step_info "Serial getty override não encontrado — nada a remover"
    fi

    # ── Encerra sessões do orangepi ───────────────────────────────────────────
    step_info "Encerrando processos do usuário orangepi..."
    pkill -9 -u orangepi 2>/dev/null || true
    sleep 1
    step_ok "Processos encerrados"

    # ── Remove usuário e home ─────────────────────────────────────────────────
    step_info "Removendo usuário e home directory..."
    deluser --remove-home orangepi 2>/dev/null && \
        step_ok "Usuário ${BOLD}orangepi${RESET} removido com sucesso" || \
        step_err "Falha ao remover usuário orangepi"

    # ── Recarrega systemd ─────────────────────────────────────────────────────
    systemctl daemon-reload 2>/dev/null || true
    step_ok "systemd recarregado"

    echo ""
    state_set "etapa5" "1"
    step_ok "${BOLD}Etapa 5 concluída.${RESET}"

    # ── Mensagem final ────────────────────────────────────────────────────────
    echo ""
    printf "${BOLD}${GREEN}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║                                                              ║"
    echo "  ║          ✔  Instalação Completa — Ghost Node Nation         ║"
    echo "  ║                                                              ║"
    echo "  ║   Próximos passos:                                           ║"
    echo "  ║   • Faça login com o usuário pleb                            ║"
    echo "  ║   • Altere a senha padrão: passwd                            ║"
    echo "  ║   • Verifique /home/pleb/halfin e /home/pleb/satoshi         ║"
    echo "  ║                                                              ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    printf "${RESET}\n"

    press_enter
    show_menu
}

# ══════════════════════════════════════════════════════════════════════════════
# EXECUÇÃO SEQUENCIAL DE TODAS AS ETAPAS
# ══════════════════════════════════════════════════════════════════════════════

run_all() {
    header
    echo ""
    printf "  ${YELLOW}${BOLD}Execução Automática — Todas as Etapas${RESET}\n\n"
    printf "  Isso irá executar as etapas 1 a 5 em sequência,\n"
    printf "  confirmando apenas ações críticas.\n"
    echo ""

    if ! confirm "Confirma a execução completa?"; then
        show_menu; return
    fi

    # Executa etapas em sequência — cada uma chama show_menu ao final,
    # por isso encadeamos via state para controle de fluxo
    etapa1 && etapa2 && etapa3 && etapa4 && etapa5 || true
}

# ══════════════════════════════════════════════════════════════════════════════
# PONTO DE ENTRADA
# ══════════════════════════════════════════════════════════════════════════════
# Suporta flag --auto para execução completa sem menu (útil para scripts)
# Exemplo: curl -fsSL <url>/install.sh | sudo bash -s -- --auto

ARG="${1:-}"
case "$ARG" in
    --auto)
        init_state
        header
        echo ""
        printf "  ${CYAN}Modo automático ativado — executando todas as etapas.${RESET}\n"
        press_enter
        run_all
        ;;
    *)
        init_state
        header
        show_menu
        ;;
esac