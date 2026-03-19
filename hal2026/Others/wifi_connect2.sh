#!/bin/sh
#
# Script para configurar Wi-Fi via Netplan no Ubuntu Server 25.04
# Node Halfin - v0.4 (Raspberry Pi 3+)
#

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

    # Se o arquivo não existe, criar novo
    if [ ! -f "$YAML_FILE" ]; then
        echo "[INFO] Criando novo arquivo Netplan: $YAML_FILE"
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
        chmod 600 "$YAML_FILE"
        return 0
    fi

    echo "[INFO] Atualizando arquivo existente: $YAML_FILE"

    # Verificar permissões
    CURRENT_PERMS=$(stat -c "%a" "$YAML_FILE")
    if [ "$CURRENT_PERMS" -ne 600 ]; then
        echo "[AVISO] Corrigindo permissões (atual: $CURRENT_PERMS, definindo para 600)"
        chmod 600 "$YAML_FILE"
    fi

    # Verificar se a rede já existe
    if grep -q "^\s*\"$SSID\":$" "$YAML_FILE"; then
        echo "[AVISO] A rede '$SSID' já está configurada. Atualizando senha."

        # Encontrar a linha da senha atual
        SSID_LINE=$(grep -n "^\s*\"$SSID\":$" "$YAML_FILE" | cut -d: -f1)
        if [ -z "$SSID_LINE" ]; then
            echo "[ERRO] Não foi possível encontrar a rede no arquivo."
            return 1
        fi

        # Procurar a próxima linha de senha após o SSID
        PASSWORD_LINE=$((SSID_LINE + 1))
        if ! sed -n "${PASSWORD_LINE}p" "$YAML_FILE" | grep -q "password:"; then
            echo "[ERRO] Estrutura do arquivo inválida."
            return 1
        fi

        # Atualizar senha
        TEMP_FILE=$(mktemp)
        sed "${PASSWORD_LINE}s/^\(\s*password:\s*\).*/\1\"$PSK\"/" "$YAML_FILE" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$YAML_FILE"
        chmod 600 "$YAML_FILE"
        return 0
    fi

    # Adicionar nova rede
    echo "[INFO] Adicionando nova rede: $SSID"

    # Encontrar ponto de inserção (último access-point)
    LAST_AP_LINE=$(grep -n "access-points:" "$YAML_FILE" | tail -1 | cut -d: -f1)
    if [ -z "$LAST_AP_LINE" ]; then
        echo "[ERRO] Não foi encontrado 'access-points:' no arquivo."
        return 1
    fi

    # Encontrar linha do último SSID
    LAST_SSID_LINE=0
    while read -r line; do
        CURRENT_LINE=$(echo "$line" | cut -d: -f1)
        if [ "$CURRENT_LINE" -gt "$LAST_AP_LINE" ] &&
           echo "$line" | grep -q "^\s*\".*\":$"; then
            LAST_SSID_LINE=$CURRENT_LINE
        fi
    done < <(grep -n "^\s*\".*\":$" "$YAML_FILE")

    INSERT_LINE=$((LAST_SSID_LINE > 0 ? LAST_SSID_LINE + 2 : LAST_AP_LINE + 1))

    # Preparar novo conteúdo
    NEW_CONTENT="        \"$SSID\":\n          password: \"$PSK\""

    # Inserir nova rede
    TEMP_FILE=$(mktemp)
    if [ "$LAST_SSID_LINE" -eq 0 ]; then
        # Caso não haja redes ainda, adicionar nova rede após access-points
        sed "${LAST_AP_LINE} a\\$NEW_CONTENT" "$YAML_FILE" > "$TEMP_FILE"
    else
        # Inserir após a última configuração de rede
        sed "${INSERT_LINE} i\\$NEW_CONTENT" "$YAML_FILE" > "$TEMP_FILE"
    fi

    mv "$TEMP_FILE" "$YAML_FILE"
    chmod 600 "$YAML_FILE"
}

aplicar_netplan() {
    echo "[INFO] Aplicando configuração com netplan..."
    netplan generate && netplan apply
    if [ $? -eq 0 ]; then
        echo "[SUCESSO] Rede '$SSID' adicionada à interface '$IFACE'."
    else
        echo "[ERRO] Falha ao aplicar configuração com Netplan."
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
}

main