#!/bin/sh
# Script de instalação do Node Halfin - v0.8 13032026
#
# Script para Orange Pi Zero 3 - Debian Bookworm
#
# echo "###### Update e Upgrade de firmwares do sistema ######"
#
# sudo fwupdmgr refresh
# Update
# sudo fwupdmgr update -y
#
# Remove Dnsmasq-base
#sudo apt remove dnsmasq-base -y
############ Sistema de Wifi e Rede Lan ##############
./alias.sh
# Access Point com WPA2, bridge br0 e Netplan - Ubuntu 25.04

SSID="Halfin"
WPA2_PASS="Mudar102030"
AP_IFACE="wlan0"
BRIDGE_IFACE="br0"
BRIDGE_IP="10.21.21.1"
NETMASK="255.255.255.0"
DHCP_START="10.21.21.100"
DHCP_END="10.21.21.105"
WAN_CANDIDATAS="end0" #wlan1
DNSMASQ_CONF="/etc/dnsmasq.conf"
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
NETPLAN_FILE="/etc/network/interfaces"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERRO] Este script precisa ser executado como root."
        exit 1
    fi
}

detectar_wan() {
    echo "[INFO] Detectando interface WAN..."
    for iface in "${WAN_CANDIDATAS[@]}"; do
        if ip link show "$iface" | grep -q "state UP"; then
            WAN_IFACE=$iface
            echo "[OK] Interface WAN detectada: $WAN_IFACE"
            return
        fi
    done

    echo "[ERRO] Nenhuma interface WAN ativa encontrada (end0 ou wlan1)."
    exit 1
}

configurar_bridge() {
    echo "[INFO] Gerando configuração bridge $BRIDGE_IFACE..."

sudo cp /etc/network/interfaces /etc/network/bkp.interfaces </dev/tty

    cat <<EOF > "$NETPLAN_FILE"
# Interface loopback
auto lo
iface lo inet loopback

# Interface Ethernet (WAN)
allow-hotplug end0
iface end0 inet dhcp

# Interface WiFi
allow-hotplug wlan0
iface wlan0 inet manual

# Bridge interface
auto br0
iface br0 inet static
    address 10.21.21.1
    netmask 255.255.255.0
    bridge_ports wlan0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0

EOF

echo "Reiniciando os serviços de rede..."
#sudo systemctl restart networking

}

######## HOSTAPD Wi-Fi Interno ##########

configurar_hostapd() {
    echo "[INFO] Criando configuração WPA2 do hostapd..."

    cat <<EOF > "$HOSTAPD_CONF"
interface=$AP_IFACE
driver=nl80211
### SSID e Auteticação ###
ssid=$SSID
country_code=BR

######## 'g' Para 2.4GHz (use "a" para 5 GHz se suportado) ########
hw_mode=a
#hw_mode=g

######## '0-11' Para 2.4Ghz ########
channel=36 # Canal primário (DFS)
#channel=6

# Segurança WPA2
auth_algs=1
wpa=2
wpa_passphrase=Mudar102030
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP

# Configurações de canal avançadas (80MHz)
ht_capab=[HT40+][SHORT-GI-40][DSSS_CCK-40][MAX-AMSDU-7935]
vht_oper_chwidth=1  # Largura de canal 80MHz (0=20/40MHz, 1=80MHz, 2=160MHz)
vht_oper_centr_freq_seg0_idx=42  # Canal central para 80MHz

#### Otimizações para 5Ghz ####

ieee80211ac=1
# Habilita Wi-Fi 5 (802.11ac)
#ieee80211n=1
# Habilita 802.11n
ieee80211d=1
# Conformidade regulatória
ieee80211h=1
# Necessário para canais DFS (se usado)
wmm_enabled=1
macaddr_acl=0
ignore_broadcast_ssid=0

# Configurações de potência maximizada
#tx_power=30       # Máximo permitido por lei (ajuste conforme regulamentação local)
#beacon_int=100    # Intervalo de beacon aumentado
#dtim_period=3     # Período DTIM otimizado

# Configurações de taxa de transmissão
#supported_rates=60 120 240 360 480 540
#basic_rates=60 120 240
#vht_capab=[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP3]

# Bridge
bridge=$BRIDGE_IFACE
EOF

    sed -i 's|#DAEMON_CONF=.*|DAEMON_CONF="'"$HOSTAPD_CONF"'"|' /etc/default/hostapd

    systemctl unmask hostapd
    systemctl enable hostapd
    systemctl restart hostapd
}

configurar_nat() {
    echo "[INFO] Ativando NAT para acesso à internet..."

    sysctl -w net.ipv4.ip_forward=1
    grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

    iptables-save > /etc/iptables.rules

    cat <<EOF > /etc/network/if-up.d/iptables

iptables-restore < /etc/iptables.rules
EOF

    chmod +x /etc/network/if-up.d/iptables
}

finalizar() {
    echo "[SUCESSO] Access Point '$SSID' criado na interface $AP_IFACE (bridge $BRIDGE_IFACE)"
    echo "[INFO] DHCP: $DHCP_START a $DHCP_END | Gateway: $(ip route | grep default | awk '{print $3}')"
    echo "[INFO] Clientes terão acesso à internet via $WAN_IFACE"
}

main() {
    check_root
    detectar_wan
    configurar_bridge
    configurar_dnsmasq
    configurar_hostapd
    configurar_nat
    finalizar
}

main

########## LAN DHCP ##########

#######################################
##### Criação das regras Firewall #####

# IP Forwarding
#echo 1 > /proc/sys/net/ipv4/ip_forward

# Detectar interface WAN (se necessário)
#WAN_IFACE=$(ip route | grep default | awk '{print $5}')
#WAN_IFACE=wan1

# Reaplicar regras NAT
#sudo iptables -t nat -F
#sudo iptables -F

#sudo iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
#sudo iptables -A FORWARD -i "$WAN_IFACE" -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
#sudo iptables -A FORWARD -i br0 -o "$WAN_IFACE" -j ACCEPT

# Salvar regras para persistência
#sudo iptables-save > /etc/iptables.rules

# Criar script de restauração em boot
#cat <<EOF | sudo tee /etc/network/if-up.d/iptables
#!/bin/sh
#iptables-restore < /etc/iptables.rules
#EOF

#sudo chmod +x /etc/network/if-up.d/iptables

#######################################
# fail2ban Instalation Script
extras/./fail2ban.sh </dev/tty

#######################################
# Pi-hole Instalation Script
extras/./pi-hole.sh </dev/tty

#######################################
# Docker Instalation Script
docker/./docker.sh </dev/tty

#######################################
# Routing Network Script
./routing.sh </dev/tty

#######################################
#######################################
echo "##### criando Aliases #####"
echo '# Agora ls é colorido, frufru.
alias ls="ls -la --color"
# IP mais detalhado
alias ip="ip -c -br -a"
# Update simples
alias update="sudo apt update && sudo apt upgrade"
# Verificando Portas
alias ports="sudo netstat -tulanp"
# Mostrando tamanho dos arquvios
alias filesize="du -sh * | sort -h"
# Ultimos comandos
alias gh="history|grep"
# ?
alias nf="neofetch"
# cd ..
alias ..="cd .."
#
alias c="clear"
# VIM
alias vi="vim"
# Sudo
alias root="sudo -i"
#
' >> $HOME/.bash_aliases

chown -R pleb:pleb /home/pleb/

#echo "###### Atualizando ########"
echo "Execute: source .bashrc"

exit 0

