#!/bin/bash

# Script Halfin Install - Ghost Nodes v0.2 19032026

if [ "$EUID" -ne 0 ]; then
    echo "[ERRO] Este script precisa ser executado como root."
    exit 1
fi

# Verificação do estágio da instalação
1. Primeira execução
    - se for a primeira execução, confirmar que está sendo executado em um sistema debian arm64 sob o hardware orangepi zero 3 ou exit
    - verificar que o usuário "orangepi" está instalado
    - verificar se o usuário "pleb" não foi criado. Caso não exista executar essas tarefas:
       
################### instalação do usuário novo ##################
1.1. echo "###### Pré-Instalação e Configurações ######"

# Criação do usuário pleb
sudo adduser --disabled-password --gecos "" pleb
echo "pleb:Mudar123" | sudo chpasswd
sudo usermod -aG sudo pleb

echo "
#### Alteração do Sourcelist APT - Debian original ####
"
sudo echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
#deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
#deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" > /etc/apt/sources.list

rm /etc/apt/sources.list.d/docker.list
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
#
cd /home/pleb/
sudo echo "halfin" > /etc/hostname
#
################### Fim da instalação do usuário novo #################
#
2. Caso as verificações tenham sido completadas ou executadas anteriormente, seguir com a etapa 2
    - Verificar se os passos anteriores foram concluídos
    - usuário novo criado e novas listas do sourcelist estão corretas
    - seguir para a próxima etapa.
################### Atualização do sistema e instalação das ferramentas ###################
#
echo "##### Atualizando o Sistema #####"
sudo apt update && sudo apt upgrade -y

echo "##### Instalando as Ferramentas Necessárias #####"
sudo apt install -y git htop vim net-tools nmap tree lm-sensors dos2unix  openssh-server iptraf-ng hostapd iptables iw traceroute bridge-utils iptables-persistent btop sqlite3 ca-certificates curl gnupg lsb-release
################### Fim da Atualização do sistema e instalação das ferramentas ###################
#
3. Caso as etapadas 1 e 2 tenham sido concluídas, seguir para a próxima
################### Download e Preparação do Projeto Ghost Nodes ###################
#
echo -e  "${GREEN}"
echo -e  "##################################"
echo -e  "## Welcome to Ghost Node Nation ##"
echo -e  "##################################${NC}"

# Download do Projeto Completo
echo "[INFO] Baixando projeto..."
wget https://github.com/k3zeus/nodenation/archive/refs/tags/beta_v2.tar.gz /home/pleb/ || exit 1
tar -xzvf /home/pleb/beta_v2.tar.gz || exit 1

# Converter line endings (se necessário)
echo "[INFO] Convertendo line endings..."
sudo find /home/pleb/ -type f -name "*.sh" -print0 | xargs -0 sudo dos2unix

echo "[INFO] Concedendo permissões..."
echo -e  ""
sudo find /home/pleb/ -name "*.sh" -type f -print0 | xargs -0 sudo chmod +x

# Ajustando as pastas
echo "[INFO] Movendo as pastas..."
mv nodenation-beta_v2/hal2026 /home/pleb/halfin 
mv nodenation-beta_v2/satoshi /home/pleb/satoshi || exit 1

# Pré instalação OrangePi Zero 3
echo "[INFO] Iniciando Instalação..."
cd /home/pleb/halfin/
./script_orange3.sh 

|| exit 1


# Ultimo comando remover usuário não mais necessário
#
echo "###### Remoção do usuário Orangepi ######"
sudo rm /lib/systemd/system/getty@.service.d/override.conf
sudo rm /lib/systemd/system/serial-getty@.service.d/override.conf
sudo pkill -9 -u orangepi
sudo deluser --remove-home orangepi
#
# Fim do script
