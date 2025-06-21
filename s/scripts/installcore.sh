#!/bin/bash

echo "Atualizando seu Servidor Ubuntu"
sudo apt update && sudo apt upgrade

apt install net-tools vim htop lm-sensors nmap -y

sensors

echo "
#!/bin/bash

sensors

paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -s $'\t' -t | sed 's/\(.\)..$/.\1°C/'

" > temp.sh

sudo chmod 755 temp.sh

######### Instalação via Bitcoin.Org Ubuntu #########

echo "Instalando a versão mais recente do Bitcoin Core"

wget -c https://bitcoincore.org/bin/bitcoin-core-28.0/bitcoin-28.0-x86_64-linux-gnu.tar.gz
tar xzvf bitcoin-28.0-x86_64-linux-gnu.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-28.0/bin/*

echo "Configuração do servidor Bitcoin Core - Finalizada"

### Fulcrum
echo "Instalando o Fulcrum - Electrum Server"

sudo apt install libssl-dev
sudo ufw allow 50001/tcp #comment 'allow Fulcrum TCP from anywhere'
sudo ufw allow 50002/tcp #comment 'allow Fulcrum SSL from anywhere'

echo "# Enable ZMQ blockhash notification (for Fulcrum)
zmqpubhashblock=tcp://127.0.0.1:8433" >> bitcoin-28.0/bitcoin.conf

echo "Configure o serviço Bitcoin na Inicialização!
Execute o comando $crontab -e
E adicione na ultima linha esse comando:
@reboot bitcoind -daemon"

echo "
Execute o arquivo bitcoin.sh para inicializar seu servidor
Ou reinicie o seu Node
"

echo "
#################

Após essa configuração seu servidor estará instalado
                e
   inicializando junto com o sistem

"
#



#
#
########## Instalação via SNAP ##############
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