#!/bin/bash

################################################################################
# Script de Recuperação de Interfaces de Rede
# Orange Pi Zero 3 - Debian 6.1 Bookworm
# Interfaces: end0, wlan0, wlan1, br0
################################################################################

# Configurações
LOG_FILE="/home/pleb/test_connect.log"
INTERFACES_SYSTEM="/etc/network/interfaces"
INTERFACES_BACKUP="/home/pleb/halfin/Files/intefaces"
INTERFACES_TO_CHECK=("end0" "wlan0" "wlan1" "br0")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Cores para output (opcional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Funções de Log
################################################################################

log_info() {
    echo "[${TIMESTAMP}] [INFO] $1" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo "[${TIMESTAMP}] [WARN] $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[${TIMESTAMP}] [ERROR] $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo "[${TIMESTAMP}] [SUCCESS] $1" | tee -a "${LOG_FILE}"
}

################################################################################
# Função para verificar se interface está UP
################################################################################

is_interface_up() {
    local interface=$1
    
    if ip link show "${interface}" &>/dev/null; then
        if ip link show "${interface}" | grep -q "state UP"; then
            return 0  # Interface está UP
        else
            return 1  # Interface existe mas está DOWN
        fi
    else
        return 2  # Interface não existe
    fi
}

################################################################################
# Função para verificar interfaces
################################################################################

check_interfaces() {
    log_info "========== Iniciando verificação de interfaces =========="
    
    local interfaces_down=()
    local interfaces_missing=()
    
    for iface in "${INTERFACES_TO_CHECK[@]}"; do
        is_interface_up "${iface}"
        local status=$?
        
        case ${status} in
            0)
                log_success "Interface ${iface} está UP"
                ;;
            1)
                log_warn "Interface ${iface} está DOWN"
                interfaces_down+=("${iface}")
                ;;
            2)
                log_error "Interface ${iface} não existe no sistema"
                interfaces_missing+=("${iface}")
                ;;
        esac
    done
    
    # Retorna 0 se todas interfaces estão UP, 1 caso contrário
    if [ ${#interfaces_down[@]} -eq 0 ] && [ ${#interfaces_missing[@]} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Função para limpar regras do iptables
################################################################################

clear_iptables() {
    log_info "Limpando regras do iptables..."
    
    # Flush todas as regras
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -t raw -F
    
    # Deletar chains customizadas
    iptables -X
    iptables -t nat -X
    iptables -t mangle -X
    iptables -t raw -X
    
    # Setar políticas padrão para ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    if [ $? -eq 0 ]; then
        log_success "Iptables limpo com sucesso"
        
        # Mostrar regras atuais no log
        log_info "Estado atual do iptables:"
        iptables -L -n -v >> "${LOG_FILE}" 2>&1
        
        return 0
    else
        log_error "Falha ao limpar iptables"
        return 1
    fi
}

################################################################################
# Função para verificar e restaurar arquivo interfaces
################################################################################

check_and_restore_interfaces_file() {
    log_info "Verificando arquivo ${INTERFACES_SYSTEM}..."
    
    # Verificar se o backup existe
    if [ ! -f "${INTERFACES_BACKUP}" ]; then
        log_error "Arquivo de backup ${INTERFACES_BACKUP} não encontrado!"
        return 1
    fi
    
    # Verificar se o arquivo do sistema existe
    if [ ! -f "${INTERFACES_SYSTEM}" ]; then
        log_warn "Arquivo ${INTERFACES_SYSTEM} não existe. Criando do backup..."
        cp "${INTERFACES_BACKUP}" "${INTERFACES_SYSTEM}"
        log_success "Arquivo ${INTERFACES_SYSTEM} criado do backup"
        return 0
    fi
    
    # Comparar os arquivos
    if diff -q "${INTERFACES_SYSTEM}" "${INTERFACES_BACKUP}" &>/dev/null; then
        log_info "Arquivo ${INTERFACES_SYSTEM} está correto (idêntico ao backup)"
        return 0
    else
        log_warn "Arquivo ${INTERFACES_SYSTEM} difere do backup"
        log_info "Diferenças encontradas:"
        diff "${INTERFACES_SYSTEM}" "${INTERFACES_BACKUP}" >> "${LOG_FILE}" 2>&1
        
        # Fazer backup do arquivo atual antes de substituir
        local backup_corrupted="${INTERFACES_SYSTEM}.corrupted.$(date +%Y%m%d_%H%M%S)"
        cp "${INTERFACES_SYSTEM}" "${backup_corrupted}"
        log_info "Backup do arquivo corrompido salvo em: ${backup_corrupted}"
        
        # Copiar arquivo correto
        cp "${INTERFACES_BACKUP}" "${INTERFACES_SYSTEM}"
        
        if [ $? -eq 0 ]; then
            log_success "Arquivo ${INTERFACES_SYSTEM} restaurado do backup"
            return 0
        else
            log_error "Falha ao restaurar arquivo ${INTERFACES_SYSTEM}"
            return 1
        fi
    fi
}

################################################################################
# Função para reiniciar networking
################################################################################

restart_networking() {
    log_info "Reiniciando serviço de rede..."
    
    # Parar interfaces
    systemctl stop networking 2>&1 | tee -a "${LOG_FILE}"
    sleep 2
    
    # Iniciar interfaces
    systemctl start networking 2>&1 | tee -a "${LOG_FILE}"
    sleep 3
    
    if [ $? -eq 0 ]; then
        log_success "Serviço networking reiniciado"
        return 0
    else
        log_error "Falha ao reiniciar networking"
        return 1
    fi
}

################################################################################
# Função para levantar interfaces individualmente
################################################################################

bring_interfaces_up() {
    log_info "Tentando levantar interfaces individualmente..."
    
    for iface in "${INTERFACES_TO_CHECK[@]}"; do
        if ip link show "${iface}" &>/dev/null; then
            log_info "Levantando interface ${iface}..."
            
            # Tentar com ip link
            ip link set "${iface}" up 2>&1 | tee -a "${LOG_FILE}"
            sleep 1
            
            # Tentar com ifup como alternativa
            ifup "${iface}" 2>&1 | tee -a "${LOG_FILE}"
            sleep 1
            
            # Verificar status
            if is_interface_up "${iface}"; then
                log_success "Interface ${iface} está UP"
            else
                log_error "Interface ${iface} ainda está DOWN"
            fi
        else
            log_warn "Interface ${iface} não existe, pulando..."
        fi
    done
}

################################################################################
# Função para verificar wpa_supplicant na wlan1
################################################################################

check_wpa_supplicant() {
    log_info "Verificando wpa_supplicant na wlan1..."
    
    if pgrep -f "wpa_supplicant.*wlan1" > /dev/null; then
        log_success "wpa_supplicant está rodando na wlan1"
    else
        log_warn "wpa_supplicant não está rodando na wlan1"
        log_info "Tentando reiniciar wpa_supplicant..."
        
        # Matar processos anteriores se existirem
        pkill -f "wpa_supplicant.*wlan1"
        sleep 1
        
        # Iniciar wpa_supplicant (ajuste o caminho do config se necessário)
        if [ -f "/etc/wpa_supplicant/wpa_supplicant-wlan1.conf" ]; then
            wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf 2>&1 | tee -a "${LOG_FILE}"
        elif [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
            wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant.conf 2>&1 | tee -a "${LOG_FILE}"
        else
            log_error "Arquivo de configuração do wpa_supplicant não encontrado"
        fi
    fi
}

################################################################################
# Função para verificar conectividade
################################################################################

check_connectivity() {
    log_info "Verificando conectividade..."
    
    # Tentar ping em gateway comum
    if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
        log_success "Conectividade OK (ping 8.8.8.8 bem sucedido)"
        return 0
    else
        log_warn "Sem conectividade externa (ping 8.8.8.8 falhou)"
        return 1
    fi
}

################################################################################
# Função Principal
################################################################################

main() {
    log_info "==========================================================="
    log_info "Script de Recuperação de Rede - Orange Pi Zero 3"
    log_info "==========================================================="
    
    # Verificar se está rodando como root
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script precisa ser executado como root (sudo)"
        exit 1
    fi
    
    # 1. Verificar estado das interfaces
    if check_interfaces; then
        log_success "Todas as interfaces estão UP"
        check_connectivity
        log_info "========== Verificação concluída - Sistema OK =========="
        exit 0
    fi
    
    log_warn "Problemas detectados nas interfaces. Iniciando recuperação..."
    
    # 2. Limpar iptables
    log_info "PASSO 1: Limpando iptables"
    clear_iptables
    
    # 3. Verificar e restaurar arquivo interfaces
    log_info "PASSO 2: Verificando arquivo /etc/network/interfaces"
    check_and_restore_interfaces_file
    
    # 4. Reiniciar networking
    log_info "PASSO 3: Reiniciando serviço networking"
    restart_networking
    
    # 5. Verificar wpa_supplicant
    log_info "PASSO 4: Verificando wpa_supplicant"
    check_wpa_supplicant
    
    # 6. Levantar interfaces individualmente
    log_info "PASSO 5: Levantando interfaces"
    bring_interfaces_up
    
    # 7. Aguardar estabilização
    log_info "Aguardando 5 segundos para estabilização..."
    sleep 5
    
    # 8. Verificação final
    log_info "========== Verificação Final =========="
    check_interfaces
    check_connectivity
    
    # 9. Resumo final
    log_info "==========================================================="
    log_info "Status final das interfaces:"
    for iface in "${INTERFACES_TO_CHECK[@]}"; do
        if ip link show "${iface}" &>/dev/null; then
            ip addr show "${iface}" | grep -E "inet |state" >> "${LOG_FILE}" 2>&1
        fi
    done
    log_info "==========================================================="
    
    log_info "Script finalizado. Verifique o log em: ${LOG_FILE}"
}

################################################################################
# Executar script
################################################################################

main "$@"
