#!/bin/bash
#
# Script for isntallation of Bitcoin Core Nodes - @K3zeus v.0.3

#echo "Atualizando seu Servidor Ubuntu"
#sudo apt update && sudo apt upgrade

#apt install net-tools vim htop lm-sensors nmap -y
echo ""
echo "###################################"
echo "# Chose your Bitcoin Core Version #"
echo "###################################"
echo " [1] bitcoin-core-28.0"
echo " [2] bitcoin-core-27.2"
echo " [3] bitcoin-core-25.0"
echo " [4] bitcoin-core-0.13.2"
echo ""
read -p " Chose version (1-4): " chose
echo ""

######### Instalação via Bitcoin.Org Ubuntu #########
case $chose in
#
# Variáveis
1)
echo ""
echo " Version 28.0 Chosed "
echo ""
echo "###################################"
echo "###### What your Archteture #######"
echo "###################################"
echo " [1] Ubuntu Server x86 - PC"
echo " [2] Raspberry Pi - Arm64"
echo " [3] Apple - Darwin"
echo " [4] Riscv64 - Archteture"
echo " [5] Exit"
echo ""

        v="bitcoin-28.0"

read -p " Chose Archteture (1 - 4): " arq
case $arq in
        1)
        vers=$v"-x86_64-linux-gnu"
        ;;
        2)
        vers=$v"-arm-linux-gnueabihf"
        ;;
        3)
        vers=$v"-arm64-apple-darwin"
        ;;
        4)
        vers=$v"-riscv64-linux-gnu"
        ;;        
        *)
        echo " Wrong choice, good by!"
        exit 1
        ;;
esac
;;

2)
echo ""
echo " Version 27.2 Chosed "
echo ""
echo "###################################"
echo "###### What your Archteture #######"
echo "###################################"
echo " [1] Ubuntu Server x86 - PC"
echo " [2] Raspberry Pi - Arm64"
echo " [3] Apple - Darwin"
echo " [4] Riscv64 - Archteture"
echo " [5] Exit"
echo ""

        v="bitcoin-27.2"

read -p " Chose Archteture (1 - 4): " arq
case $arq in
        1)
        vers=$v"-x86_64-linux-gnu"
        ;;
        2)
        vers=$v"-arm-linux-gnueabihf"
        ;;
        3)
        vers=$v"-arm64-apple-darwin"
        ;;
        4)
        vers=$v"-riscv64-linux-gnu"
        ;;        
        *)
        echo " Wrong choice, good by!"
        exit 1
        ;;
esac
;;

3)
echo ""
echo " Version 25.0 Chosed "
echo ""
echo "###################################"
echo "###### What your Archteture #######"
echo "###################################"
echo " [1] Ubuntu Server x86 - PC"
echo " [2] Raspberry Pi - Arm64"
echo " [3] Apple - Darwin"
echo " [4] Riscv64 - Archteture"
echo " [5] Exit"
echo ""

        v="bitcoin-25.0"

read -p " Chose Archteture (1 - 4): " arq
case $arq in
        1)
        vers=$v"-x86_64-linux-gnu"
        ;;
        2)
        vers=$v"-arm-linux-gnueabihf"
        ;;
        3)
        vers=$v"-arm64-apple-darwin"
        ;;
        4)
        vers=$v"-riscv64-linux-gnu"
        ;;        
        *)
        echo " Wrong choice, good by!"
        exit 1
        ;;
esac
;;

4)
echo ""
echo " Version 0.13.2 Chosed "
echo ""
echo "###################################"
echo "###### What your Archteture #######"
echo "###################################"
echo " [1] Ubuntu Server x86 - PC"
echo " [2] Raspberry Pi - Arm64"
echo " [3] Apple - Darwin"
echo " [4] Riscv64 - Archteture"
echo " [5] Exit"
echo ""

        v="bitcoin-0.13.2"

read -p " Chose Archteture (1 - 4): " arq
case $arq in
        1)
        vers=$v"-x86_64-linux-gnu"
        ;;
        2)
        vers=$v"-arm-linux-gnueabihf"
        ;;
        3)
        vers=$v"-arm64-apple-darwin"
        ;;
        4)
        vers=$v"-riscv64-linux-gnu"
        ;;        
        *)
        echo " Wrong choice, good by!"
        exit 1
        ;;
esac
;;

*)
echo " Invalid Option, good bye....."
exit 1
;;
esac
#
echo ""
echo "Instalando a versão $v do Bitcoin Core"

wget -P /root/ -c https://bitcoincore.org/bin/$v/$vers.tar.gz
tar xzvf /root/$vers.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin /root/$v/bin/*
rm -r $vers.tar.gz

echo ""
echo "# Configuração do servidor Bitcoin Core - Finalizada #"
echo "######################################################"
echo ""
echo "######################################################"
echo " Instalar o Serviço Fulcrum?"
echo ""
echo " É necessário ter espaço extra"
echo " Mais de 300Gb recomendado além do Core"
echo " para utilizar o serviço"
echo ""
echo "######################################################"
echo " Escolha 1 para instalar"
echo " Escolha 2 para não instalar"
echo ""

read -p " Digite sua escolha: " escolha
echo ""

case $escolha in

        1)

#############################################
### Fulcrum
echo "Instalando o Fulcrum - Electrum Server"

sudo apt install libssl-dev
sudo ufw allow 50001/tcp #comment 'allow Fulcrum TCP from anywhere'
sudo ufw allow 50002/tcp #comment 'allow Fulcrum SSL from anywhere'

echo "# Enable ZMQ blockhash notification (for Fulcrum)
zmqpubhashblock=tcp://127.0.0.1:8433" >> $vers/bitcoin.conf

;;
        2)

echo "#####################################################"
echo " Continuando a instalação sem Fulcrum..."
echo "#####################################################"
echo ""
echo ""
echo "#####################################################"
echo " Configure o serviço Bitcoin na Inicialização!"
echo " Execute o comando crontab -e"
echo " E adicione na ultima linha esse comando: "
echo ""
echo " @reboot bitcoind -daemon"
echo ""
echo "#####################################################"
echo ""
echo "#####################################################"
echo "######### Execute o arquivo bitcoin.sh para #########"
echo "############# inicializar seu servidor ##############"
echo "############## Ou reinicie o seu Node ###############"
echo "#####################################################"
echo ""
echo "#####################################################"
echo " Após essa configuração seu servidor estará instalado"
echo " e "
echo " Inicializando junto com o sistema"
echo "#####################################################"
echo ""
#
rm -r /root/nodenation

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
