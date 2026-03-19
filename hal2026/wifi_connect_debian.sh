#!/bin/bash
#
# WiFi Connect Script - Wireless Interface and Scan Network - Ghost Nodes v0.2 18032026
#
# Configurações
CONFIG_DIR="/etc/wifi_config"
NETWORK_INTERFACES="/etc/network/interfaces"
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
LOG_FILE="$CONFIG_DIR/wifi_connections.log"
WPA_SUPPLICANT_SERVICE="/etc/systemd/system/wpa_supplicant.service"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para inicializar o ambiente
initialize() {
    # Criar diretório de configuração se não existir
    mkdir -p "$CONFIG_DIR"

    # Criar arquivo de log se não existir
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        echo "Data,Interface,SSID" > "$LOG_FILE"
    fi

    # Verificar se script está sendo executado como root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Este script deve ser executado como root!${NC}"
        exit 1
    fi
}

# Função para listar interfaces wireless disponíveis
list_wireless_interfaces() {
    echo -e "${BLUE}Interfaces wireless disponíveis:${NC}"
    interfaces=($(iw dev | awk '$1=="Interface"{print $2}'))

    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Nenhuma interface wireless encontrada!${NC}"
        exit 1
    fi

    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done
}

# Função para selecionar interface
select_interface() {
    while true; do
        read -p "Selecione a interface (número): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#interfaces[@]} ]; then
            SELECTED_INTERFACE="${interfaces[$((choice-1))]}"
            break
        else
            echo -e "${RED}Seleção inválida!${NC}"
        fi
    done
}

# Função para escanear redes WiFi
scan_networks() {
    echo -e "${BLUE}Escaneando redes disponíveis na interface $SELECTED_INTERFACE...${NC}"

    # Ativar interface
    ip link set dev "$SELECTED_INTERFACE" up
    sleep 2

    # Escanear redes
    networks=$(iw dev "$SELECTED_INTERFACE" scan | grep -E "SSID|signal" | awk -F ': ' '{
        if ($1 ~ /SSID/) {ssid=$2}
        if ($1 ~ /signal/) {printf "%-30s %s\n", ssid, $2}
    }' | sort -k2 -nr | uniq)

    if [ -z "$networks" ]; then
        echo -e "${RED}Nenhuma rede encontrada!${NC}"
        exit 1
    fi

    echo -e "${GREEN}Redes disponíveis:${NC}"
    echo "$networks" | nl -w 2 -s '. '
}

# Função para selecionar rede
select_network() {
    network_count=$(echo "$networks" | wc -l)

    while true; do
        read -p "Selecione a rede (número) ou digite '0' para inserir manualmente: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "$network_count" ]; then
            if [ "$choice" -eq 0 ]; then
                read -p "Digite o SSID da rede: " SELECTED_SSID
            else
                SELECTED_SSID=$(echo "$networks" | sed -n "${choice}p" | awk '{print $1}')
            fi
            break
        else
            echo -e "${RED}Seleção inválida!${NC}"
        fi
    done
}

# Função para obter senha
get_password() {
    read -s -p "Digite a senha para '$SELECTED_SSID': " PASSWORD
    echo
}

# Função para configurar serviço wpa_supplicant
setup_wpa_supplicant_service() {
    cat > "$WPA_SUPPLICANT_SERVICE" <<EOF
[Unit]
Description=WPA supplicant
Before=network.target
After=dbus.service

[Service]
Type=dbus
BusName=fi.w1.wpa_supplicant1
ExecStart=/sbin/wpa_supplicant -u -s -O /run/wpa_supplicant

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable wpa_supplicant.service
    systemctl start wpa_supplicant.service
}

# Função para configurar conexão
configure_connection() {
    echo -e "${BLUE}Configurando conexão para $SELECTED_SSID na interface $SELECTED_INTERFACE...${NC}"

    # Configurar wpa_supplicant
    if [ ! -f "$WPA_SUPPLICANT_CONF" ]; then
        cat > "$WPA_SUPPLICANT_CONF" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=BR
EOF
    fi

    # Verificar se o wpa_supplicant.service está configurado
    if [ ! -f "$WPA_SUPPLICANT_SERVICE" ]; then
        setup_wpa_supplicant_service
    fi

    # Gerar PSK
    wpa_psk=$(wpa_passphrase "$SELECTED_SSID" "$PASSWORD" | grep -E "^\s*psk" | tail -1 | awk -F= '{print $2}')

    # Verificar se a rede já existe no arquivo
    if grep -q "ssid=\"$SELECTED_SSID\"" "$WPA_SUPPLICANT_CONF"; then
        echo -e "${YELLOW}Rede já configurada. Atualizando configuração...${NC}"
        # Remover configuração existente
        sed -i "/ssid=\"$SELECTED_SSID\"/,/}/d" "$WPA_SUPPLICANT_CONF"
    fi

    # Adicionar nova configuração
    cat >> "$WPA_SUPPLICANT_CONF" <<EOF
network={
    ssid="$SELECTED_SSID"
    psk=$wpa_psk
}
EOF

    # Configurar interface de rede
    if ! grep -q "allow-hotplug $SELECTED_INTERFACE" "$NETWORK_INTERFACES"; then
        echo "allow-hotplug $SELECTED_INTERFACE" >> "$NETWORK_INTERFACES"
        echo "iface $SELECTED_INTERFACE inet dhcp" >> "$NETWORK_INTERFACES"
        echo "    wpa-conf $WPA_SUPPLICANT_CONF" >> "$NETWORK_INTERFACES"
    fi

    # Registrar conexão no log
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$SELECTED_INTERFACE,$SELECTED_SSID" >> "$LOG_FILE"

    # Reiniciar serviços
    echo -e "${BLUE}Reiniciando serviços de rede...${NC}"
    systemctl restart wpa_supplicant
    systemctl restart networking

    # Verificar conexão
    sleep 5
    if iw dev "$SELECTED_INTERFACE" link | grep -q "Connected"; then
        echo -e "${GREEN}Conexão estabelecida com sucesso!${NC}"

        # Mostrar IP atribuído
        ip_address=$(ip addr show dev "$SELECTED_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [ -n "$ip_address" ]; then
            echo -e "${GREEN}Endereço IP: $ip_address${NC}"
        fi
    else
        echo -e "${RED}Falha ao estabelecer conexão!${NC}"
        echo -e "${YELLOW}Verifique a senha e tente novamente.${NC}"
        echo -e "${YELLOW}Debug: Verifique o status com: systemctl status wpa_supplicant${NC}"
    fi
}

# Função para mostrar estatísticas
show_stats() {
    total_connections=$(wc -l < "$LOG_FILE")
    echo -e "${BLUE}Total de conexões configuradas: $((total_connections-1))${NC}"

    if [ $total_connections -gt 1 ]; then
        echo -e "${BLUE}Últimas conexões:${NC}"
        tail -5 "$LOG_FILE" | awk -F, '{printf "%-20s %-10s %s\n", $1, $2, $3}'
    fi
}

# Função principal
main() {
    initialize

    echo -e "${GREEN}=== Configurador de Conexões WiFi ===${NC}"

    # Mostrar estatísticas
    show_stats

    # Listar e selecionar interface
    list_wireless_interfaces
    select_interface

    # Escanear e selecionar rede
    scan_networks
    select_network

    # Obter senha
    get_password

    # Configurar conexão
    configure_connection
}

# Executar função principal
main "$@"
