#!/bin/bash

echo "Escolha uma opção:"
echo "1 - Executar script_s.sh"
echo "2 - Executar script_b.sh"
echo "3 ou qualquer outra tecla - Sair"

read -p "Digite sua escolha: " escolha

case $escolha in
    1)
        if [ -f "/satoshi/script_s.sh" ]; then
            echo "Executando script_s.sh..."
	    cp /satoshi/script_s.sh /root/nodenation/
            /bin/bash /root/nodenation/script_s.sh
        else
            echo "Erro: /satoshi/script_s.sh não encontrado!"
            exit 1
        fi
        ;;
    2)
        if [ -f "/pleb/script_b.sh" ]; then
            echo "Executando script_b.sh..."
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