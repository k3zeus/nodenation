#!/bin/bash

#echo "Atualizando seu Servidor Ubuntu"
#sudo apt update && sudo apt upgrade

#apt install net-tools vim htop lm-sensors nmap -y
echo "###############################"
echo "Chose your Bitcoin Core Version"
echo "###############################"
echo " [1] bitcoin-core-28.0"
echo " [2] bitcoin-core-27.2"
echo " [3] bitcoin-core-25.0"

read -p "Chose version: " chose
######### Instalação via Bitcoin.Org Ubuntu #########
1="bitcoin-28.0"
2="bitcoin-27.1"
3="bitcoin-25.0"

echo "Instalando a versão 28.0 do Bitcoin Core"

case $chose in

wget -P /root/ -c https://bitcoincore.org/bin/$chose/$chose-x86_64-linux-gnu.tar.gz
tar xzvf /root/$chose-x86_64-linux-gnu.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin /root/$chose/bin/*
rm -r $chose-x86_64-linux-gnu.tar.gz

echo "Configuração do servidor Bitcoin Core - Finalizada"

esac

echo "
Instalar o Serviço Fulcrum?"
echo "
É necessário ter espaço extra
Mais de 300Gb recomendado além do Core
para utilizar o serviço
"
echo "Escolha 1 para instalar"
echo "Escolha 2 para não instalar"

read -p "Digite sua escolha: " escolha

case $escolha in

        1)

#############################################
### Fulcrum
echo "Instalando o Fulcrum - Electrum Server"

sudo apt install libssl-dev
sudo ufw allow 50001/tcp #comment 'allow Fulcrum TCP from anywhere'
sudo ufw allow 50002/tcp #comment 'allow Fulcrum SSL from anywhere'

echo "# Enable ZMQ blockhash notification (for Fulcrum)
zmqpubhashblock=tcp://127.0.0.1:8433" >> $chose/bitcoin.conf

;;
        2)

echo "#####################################################"
echo " Continuando a instalação sem Fulcrum..."
echo "#####################################################"
echo ""
echo "#####################################################"
echo " Configure o serviço Bitcoin na Inicialização!"
echo " Execute o comando crontab -e"
echo " E adicione na ultima linha esse comando: "
echo " @reboot bitcoind -daemon"
echo "#####################################################"
echo ""
echo "#####################################################"
echo "######### Execute o arquivo bitcoin.sh para #########"
echo "############# inicializar seu servidor ##############"
echo "############## Ou reinicie o seu Node ###############"
echo ""
echo "#####################################################"
echo "Após essa configuração seu servidor estará instalado"
echo "#                   e                               #"
echo "######### Inicializando junto com o sistem ##########"
echo "#####################################################"
#

exit 0

        ;;
esac

#
#
########## Instalação via SNAP (não recomendado) ##############
#sudo apt install snapd

#sudo snap install bitcoin-core

### Fulcrum
#echo "Instalando o Fulcrum - Electrum Server"

#sudo apt install libssl-dev
#sudo ufw allow 50001/tcp #comment 'allow Fulcrum TCP from anywhere'
#sudo ufw allow 50002/tcp #comment 'allow Fulcrum SSL from anywhere'

#echo "# Enable ZMQ blockhash notification (for Fulcrum)
#zmqpubhashblock=tcp://127.0.0.1:8433" >> /home/$USER/snap/bitcoin-core/common/.bitcoin/bitcoin.conf

#sudo ss -tulpn | grep bitcoin-core.daemon | grep 8433

#https://bitcoin.org/bin/bitcoin-core-27.0/bitcoin-27.0-x86_64-linux-gnu.tar.gz

#bitcoin-core.daemon -datadir=/home/$USER/snap/bitcoin-core/common/.bitcoin
