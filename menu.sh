#!/bin/bash
#
echo "
Escolha uma opção:
#"
echo "1 - Instalar o Halfin Node"
echo "2 - Instalar o Satoshi Node"
echo "3 - Instalar o Satoshi Node"
echo "4 - Instalar o Craig Node"
echo "5 ou qualquer outra tecla - Sair"

read -p "
Digite sua escolha: " escolha

case $escolha in
    1)
            echo "
Running o Halfyn Node..."
echo "#################################
	Qual seu equipamento?	
#################################"
echo "#################################

Ubuntu Server instalado em:
		      
[1] RaspBerry Pi + Dongle Wifi
[2] Raspberry Pi sem Dongle
[3] Banana Pi Zero
[4] Outro
#################################
"

	read -p "Escolha a sua configuração: " TIPO
	if [[ "$TIPO" == "1" ]]; then
 	git clone https://github.com/k3zeus/nodenation.git /root/
	/root/nodenation/halfin/./alias.sh
 	/root/nodenation/halfin/./script_rasp.sh
	fi
	if [[ "$TIPO" == "3" ]]; then
	curl -sS https://raw.githubusercontent.com/k3zeus/nodenation/refs/heads/main/halfyn/script_openwrt.sh | bash
	fi
	if [[ "$TIPO" == "4" ]]; then
	curl -sS https://raw.githubusercontent.com/k3zeus/nodenation/refs/heads/main/halfyn/script_rasp.sh | bash
	fi
	if [[ "$TIPO" == "2" ]]; then
	echo "Script em fase de testes"
	exit 0
	fi
	
        ;;
    2)
        if [ -f "/pleb/script_b.sh" ]; then
            echo "Instalar o Satoshi Node..."
            /bin/bash /pleb/script_b.sh
        else
            echo "Erro: /pleb/script_b.sh não encontrado!"
            exit 1
        fi
        ;;
    3)
        if [ -f "/pleb/script_b.sh" ]; then
            echo "Instalar o Satoshi Node..."
            /bin/bash /pleb/script_b.sh
        else
            echo "Erro: /pleb/script_b.sh não encontrado!"
            exit 1
        fi
        ;;
    4)
        if [ -f "/pleb/script_b.sh" ]; then
            echo "Enganando o Craig Node..."
            /bin/bash /pleb/script_b.sh
        else
            echo "Erro: /pleb/script_b.sh não encontrado!"
            exit 1
        fi
        ;;
    *)
        echo "Saindo sem executar nada."
        exit 0
        ;;
esac
