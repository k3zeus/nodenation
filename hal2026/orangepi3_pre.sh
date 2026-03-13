# Script de pré-instalação do Node Halfin - v0.1 - 13032026
#
# Script para Orange Pi Zero 3 - Debian Bookworm
#
#
echo "###### Pré-Instalação e Configurações ######"

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
echo "Remoção do usuário Orangepi"
#
cd /home/pleb/
sudo rm /lib/systemd/system/getty@.service.d/override.conf
sudo rm /lib/systemd/system/serial-getty@.service.d/override.conf
sudo pkill -9 -u orangepi
sudo deluser --remove-home orangepi
#
sudo echo "halfin" > /etc/hostname
#
echo "##### Atualizando o Sistema #####"
sudo apt update && sudo apt upgrade -y

echo "##### Instalando as Ferramentas Necessárias #####"
sudo apt install -y git htop vim net-tools nmap tree lm-sensors dos2unix  openssh-server iptraf-ng hostapd iptables iw traceroute bridge-utils iptables-persistent
#
echo -e  "${GREEN}"
echo -e  "##################################"
echo -e  "## Welcome to Ghost Node Nation ##"
echo -e  "##################################${NC}"

echo -e  ""
echo -e  "${CYAN}Download Github Project${NC}"
wget https://github.com/k3zeus/nodenation/archive/refs/tags/beta.tar.gz /home/pleb/
tar -xzvf beta.tar.gz
sudo find /home/pleb/ -type f -name "*.sh" -print0 | xargs -0 sudo dos2unix

echo -e  "${CYAN}Changing permition to scripts:${NC} "
echo -e  ""
sudo find /home/pleb/ -name "*.sh" -type f -print0 | xargs -0 sudo chmod +x
#
mv /home/pleb/nodenation-beta /home/pleb/nodenation
cd /home/pleb/nodenation/hal2026/
sudo ./script_orange3.sh
