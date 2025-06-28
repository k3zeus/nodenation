#!/bin/bash

# Script para configurar Wi-Fi via Netplan no Ubuntu Server 25.04

NETPLAN_DIR="/etc/netplan"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERRO] Este script precisa ser executado como root."
        exit 1
    fi
}

listar_interfaces_wifi() {
    echo "[INFO] Interfaces wireless disponíveis:"
    iw dev | awk '$1=="Interface"{print $2}'
}

selecionar_interface() {
    read -p "Digite o nome da interface Wi-Fi a ser configurada: " IFACE
    if ! ip link show "$IFACE" &>/dev/null; then
        echo "[ERRO] Interface '$IFACE' não encontrada."
        exit 1
    fi
}

listar_redes() {
    echo "[INFO] Escaneando redes disponíveis..."
    iw "$IFACE" scan | grep SSID | awk -F ': ' '{print $2}' | sort -u
}

capturar_dados_rede() {
    read -p "Digite o SSID da rede Wi-Fi: " SSID
    read -s -p "Digite a senha da rede Wi-Fi: " PSK
    echo
}

gerar_netplan_yaml() {
    YAML_FILE="$NETPLAN_DIR/01-${IFACE}-wifi.yaml"

    echo "[INFO] Criando arquivo Netplan em: $YAML_FILE"

    cat <<EOF > "$YAML_FILE"
network:
  version: 2
  renderer: networkd
  wifis:
    $IFACE:
      dhcp4: true
      access-points:
        "$SSID":
          password: "$PSK"
EOF
}

aplicar_netplan() {
    echo "[INFO] Aplicando configuração com netplan..."
    netplan generate && netplan apply
    if [ $? -eq 0 ]; then
        echo "[SUCESSO] Conexão Wi-Fi '$SSID' aplicada na interface '$IFACE'."
    else
        echo "[ERRO] Falha ao aplicar configuração com Netplan."
    fi
}

main() {
    check_root
    listar_interfaces_wifi
    selecionar_interface
    listar_redes
    capturar_dados_rede
    gerar_netplan_yaml
    aplicar_netplan
}

main
