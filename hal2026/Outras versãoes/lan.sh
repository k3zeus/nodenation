#!/bin/sh
#
# Node Halfin - v0.2
# Script para configurar interface de rede cabeada (Ethernet) no Ubuntu Server 25.04 com Netplan

NETPLAN_DIR="/etc/netplan"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERRO] Este script precisa ser executado como root."
        exit 1
    fi
}

listar_interfaces_ethernet() {
    echo "[INFO] Interfaces Ethernet disponíveis:"
    ip -o link show | awk -F': ' '{print $2}' | grep -E "^en|^eth"
}

selecionar_interface() {
    read -p "Digite o nome da interface Ethernet a ser configurada: " IFACE
    if ! ip link show "$IFACE" &>/dev/null; then
        echo "[ERRO] Interface '$IFACE' não encontrada."
        exit 1
    fi
}

escolher_tipo_configuracao() {
    echo
    echo "[1] Usar DHCP (IP automático)"
    echo "[2] Usar IP fixo (estático)"
    read -p "Escolha o tipo de configuração [1 ou 2]: " TIPO

    if [[ "$TIPO" == "2" ]]; then
        read -p "Digite o endereço IP (ex: 192.168.1.100): " IP
        read -p "Digite a máscara de rede (ex: 24 para 255.255.255.0): " MASK
        read -p "Digite o gateway (ex: 192.168.1.1): " GATEWAY
        read -p "Digite os servidores DNS separados por vírgula (ex: 1.1.1.1,8.8.8.8): " DNS
    fi
}

gerar_netplan_yaml() {
    YAML_FILE="$NETPLAN_DIR/02-${IFACE}-ethernet.yaml"
    echo "[INFO] Criando arquivo Netplan: $YAML_FILE"

    if [[ "$TIPO" == "1" ]]; then
        # DHCP
        cat <<EOF > "$YAML_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: true
EOF
    else
        # IP fixo
        cat <<EOF > "$YAML_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: false
      addresses: [$IP/$MASK]
      gateway4: $GATEWAY
      nameservers:
        addresses: [${DNS}]
EOF
    fi
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
    check_root
    listar_interfaces_ethernet
    selecionar_interface
    escolher_tipo_configuracao
    gerar_netplan_yaml
    aplicar_netplan
}

main