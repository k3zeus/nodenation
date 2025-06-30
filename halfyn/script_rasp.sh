#!/bin/sh
# Script de instalação do Node Halfyn - v0.2
#
sudo su
cd /root/
#
# Desativando o Cloud-Init
sudo touch /etc/cloud/cloud-init.disabled

#
echo "##### Atualizando o Sistema #####"
sudo apt update && sudo apt upgrade -y

echo "##### Instalando as Ferramentas Necessárias #####"
sudo apt install -y htop vim net-tools nmap tree lm-sensors openssh-server iptraf-ng hostapd dnsmasq iptables iw

echo "###### Update e Upgrade de firmwares do sistema ######"
#
sudo fwupdmgr refresh
#
# Update
sudo fwupdmgr update -y


############ Sistema de Wifi e Rede Lan ##############

# Access Point com WPA2, bridge br0 e Netplan - Ubuntu 25.04

SSID="Halfyn"
WPA2_PASS="Mudar102030"
AP_IFACE="wlan0"
BRIDGE_IFACE="br0"
BRIDGE_IP="10.21.21.1"
NETMASK="255.255.255.0"
DHCP_START="10.21.21.100"
DHCP_END="10.21.21.105"
WAN_CANDIDATAS=("eth0" "wlan1")
DNSMASQ_CONF="/etc/dnsmasq.conf"
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
NETPLAN_FILE="/etc/netplan/99-bridge-ap.yaml"

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

    echo "[ERRO] Nenhuma interface WAN ativa encontrada (eth0 ou wlan1)."
    exit 1
}

configurar_netplan_bridge() {
    echo "[INFO] Gerando configuração Netplan com bridge $BRIDGE_IFACE..."

    cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $WAN_IFACE:
      dhcp4: true
  wifis:
    $AP_IFACE:
      dhcp4: no
      access-points:
        "$SSID":
          password: "$WPA2_PASS"
      optional: true
  bridges:
    $BRIDGE_IFACE:
      interfaces: [$AP_IFACE]
      addresses: [$BRIDGE_IP/24]
      dhcp4: no
EOF
    netplan apply
}

configurar_dnsmasq() {
    echo "[INFO] Configurando dnsmasq para DHCP na bridge..."

    systemctl stop dnsmasq
    cat <<EOF > "$DNSMASQ_CONF"
interface=$BRIDGE_IFACE
bind-interfaces
dhcp-range=$DHCP_START,$DHCP_END,$NETMASK,12h
server=8.8.8.8
EOF
    systemctl enable dnsmasq
    systemctl restart dnsmasq
}

configurar_hostapd() {
    echo "[INFO] Criando configuração WPA2 do hostapd..."

    cat <<EOF > "$HOSTAPD_CONF"
interface=$AP_IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$WPA2_PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
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

    iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
    iptables -A FORWARD -i "$WAN_IFACE" -o "$BRIDGE_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$BRIDGE_IFACE" -o "$WAN_IFACE" -j ACCEPT

    iptables-save > /etc/iptables.rules

    cat <<EOF > /etc/network/if-up.d/iptables
#!/bin/sh
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
    configurar_netplan_bridge
    configurar_dnsmasq
    configurar_hostapd
    configurar_nat
    finalizar
}

main

########## LAN DHCP ##########

NETPLAN_DIR="/etc/netplan"
IFACE="eth0"

gerar_netplan_yaml() {
    YAML_FILE="$NETPLAN_DIR/02-${IFACE}-ethernet.yaml"
    echo "[INFO] Criando arquivo Netplan: $YAML_FILE"
       # DHCP
        cat <<EOF > "$YAML_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: true
EOF

}

aplicar_netplan() {
    echo "[INFO] Aplicando configuração com Netplan..."
    netplan generate && netplan apply
    if [ $? -eq 0 ]; then
        echo "[SUCESSO] Interface '$IFACE' configurada com sucesso."
    else
        echo "[ERRO] Houve uma falha ao aplicar a configuração Netplan."
    fi
}

main() {
    gerar_netplan_yaml
    aplicar_netplan
}

#######################################
##### Criação das regras Firewall #####
echo 1 > /proc/sys/net/ipv4/ip_forward

# Detectar interface WAN (se necessário)
WAN_IFACE=$(ip route | grep default | awk '{print $5}')

#WAN_IFACE=wan1
# Reaplicar regras NAT
sudo iptables -t nat -F
sudo iptables -F

sudo iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
sudo iptables -A FORWARD -i "$WAN_IFACE" -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i br0 -o "$WAN_IFACE" -j ACCEPT

# Salvar regras para persistência
sudo iptables-save > /etc/iptables.rules

# Criar script de restauração em boot
cat <<EOF | sudo tee /etc/network/if-up.d/iptables
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF

sudo chmod +x /etc/network/if-up.d/iptables


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

#echo "###### Atualizando ########"
echo "Execute: source .bashrc"

exit 0
