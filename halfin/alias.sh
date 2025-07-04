#!/bin/bash

# Script para renomear interfaces wireless no Ubuntu 25.04 - v.0.03
# O novo nome será aplicado via regra udev

apt install iw

UDEV_RULES_DIR="/etc/udev/rules.d"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERRO] Este script precisa ser executado como root."
        exit 1
    fi
}

listar_interfaces_wireless() {
    echo "[INFO] Buscando interfaces wireless..."
    iw dev | awk '$1=="Interface"{print $2}'
}

selecionar_interface() {
    echo
    read -p "Digite o nome da interface wireless que deseja renomear: " INTERFACE_ANTIGA
    if ! ip link show "$INTERFACE_ANTIGA" &>/dev/null; then
        echo "[ERRO] Interface '$INTERFACE_ANTIGA' não encontrada."
        exit 1
    fi
}

definir_novo_nome() {
    read -p "Digite o novo nome (alias) para a interface '$INTERFACE_ANTIGA': " INTERFACE_NOVA
    if [[ ! "$INTERFACE_NOVA" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "[ERRO] Nome inválido. Use apenas letras, números, hífen ou underline."
        exit 1
    fi
}

criar_regra_udev() {
    MAC=$(cat /sys/class/net/"$INTERFACE_ANTIGA"/address)
    RULE_FILE="$UDEV_RULES_DIR/70-renomear-$INTERFACE_ANTIGA.rules"

    echo "[INFO] Criando regra udev para renomear '$INTERFACE_ANTIGA' para '$INTERFACE_NOVA'..."

    cat <<EOF > "$RULE_FILE"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$MAC", NAME="$INTERFACE_NOVA"
EOF

    echo "[SUCESSO] Regra criada em $RULE_FILE"
}

reiniciar_rede() {
    echo "[INFO] Aplicando nova configuração (reboot pode ser necessário)..."
    udevadm control --reload
    udevadm trigger --subsystem-match=net
    echo "[INFO] Verifique com 'ip a' se o nome foi aplicado, ou reinicie o sistema."
}

main() {
    check_root
    listar_interfaces_wireless
    selecionar_interface
    definir_novo_nome
    criar_regra_udev
    reiniciar_rede
}

main
