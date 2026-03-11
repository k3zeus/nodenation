#!/bin/sh
#
# Script para configurar Wi-Fi via Netplan no Ubuntu Server 25.04
# Node Halfin - v0.5 (OrangePi 3)
#

NETPLAN_DIR="/etc/netplan"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

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

verificar_interface() {
    local iface="$1"
    if ! ip link show "$iface" &>/dev/null; then
        echo "[ERRO] Interface '$iface' não encontrada."
        return 1
    fi
    if ! iw dev "$iface" info &>/dev/null; then
        echo "[ERRO] '$iface' não é uma interface wireless."
        return 1
    fi
    return 0
}

selecionar_interface() {
    while true; do
        read -p "Digite o nome da interface Wi-Fi a ser configurada: " IFACE
        if verificar_interface "$IFACE"; then
            break
        fi
    done
}

listar_redes() {
    echo "[INFO] Escaneando redes disponíveis..."
    ip link set dev "$IFACE" up
    sleep 2
    iw dev "$IFACE" scan | grep -E "SSID|signal" | awk -F ': ' '{
        if ($1 ~ /SSID/) {ssid=$2} 
        if ($1 ~ /signal/) {printf "%-30s %s\n", ssid, $2}
    }' | sort -k2 -nr
}

capturar_dados_rede() {
    while true; do
        read -p "Digite o SSID da rede Wi-Fi: " SSID
        if [ -n "$SSID" ]; then
            break
        else
            echo "[ERRO] SSID não pode ser vazio."
        fi
    done

    while true; do
        read -s -p "Digite a senha da rede Wi-Fi: " PSK
        echo
        if [ -n "$PSK" ]; then
            break
        else
            echo "[ERRO] Senha não pode ser vazia."
        fi
    done
}

gerar_netplan_yaml() {
    # Verifica se já existe configuração para esta interface
    existing_file=$(grep -rl "wifis:" "$NETPLAN_DIR" | xargs grep -l "$IFACE:" | head -1)
    
    if [ -n "$existing_file" ]; then
        echo "[INFO] Encontrada configuração existente em: $existing_file"
        YAML_FILE="$existing_file"
        
        # Verifica se o SSID já existe
        if grep -q "$SSID:" "$YAML_FILE"; then
            echo "[AVISO] Rede '$SSID' já existe. Atualizando senha."
            # Remove configuração existente do SSID
            sed -i "/$SSID:/,/password/d" "$YAML_FILE"
        fi
        
        # Adiciona nova rede ao arquivo existente
        echo "[INFO] Adicionando nova rede ao arquivo existente"
        
        # Encontra a posição para inserção
        insert_line=$(grep -n "access-points:" "$YAML_FILE" | cut -d: -f1 | head -1)
        
        if [ -z "$insert_line" ]; then
            # Se não houver seção access-points, cria uma
            insert_line=$(grep -n "$IFACE:" "$YAML_FILE" | cut -d: -f1 | head -1)
            if [ -n "$insert_line" ]; then
                insert_line=$((insert_line + 1))
                sed -i "${insert_line}a\      access-points:" "$YAML_FILE"
                insert_line=$((insert_line + 1))
            fi
        else
            insert_line=$((insert_line + 1))
        fi
        
        if [ -n "$insert_line" ]; then
            # Prepara o bloco YAML para inserção
            config_block="        \"$SSID\":\n          password: \"$PSK\""
            sed -i "${insert_line}i$config_block" "$YAML_FILE"
        else
            echo "[ERRO] Não foi possível encontrar local para inserção."
            exit 1
        fi
    else
        # Cria novo arquivo de configuração
        YAML_FILE="$NETPLAN_DIR/99-wifi-config-$TIMESTAMP.yaml"
        echo "[INFO] Criando novo arquivo Netplan: $YAML_FILE"
        
        cat <<EOF > "$YAML_FILE"
network:
  version: 2
  renderer: networkd
  wifis:
    $IFACE:
      dhcp4: true
      dhcp6: true
      access-points:
        "$SSID":
          password: "$PSK"
EOF
    fi
}

aplicar_netplan() {
    echo "[INFO] Aplicando configuração com netplan..."
    if netplan generate && netplan apply; then
        echo "[SUCESSO] Conexão Wi-Fi '$SSID' aplicada na interface '$IFACE'."
        echo "[INFO] Verifique o status com: iw dev $IFACE link"
    else
        echo "[ERRO] Falha ao aplicar configuração com Netplan."
        echo "[INFO] Verifique os logs com: journalctl -u systemd-networkd"
        exit 1
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
    echo "[INFO] Configuração completa!"
}

main