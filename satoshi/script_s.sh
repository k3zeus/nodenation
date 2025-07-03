#!/bin/sh
#
# Instalation Configuration and Tools for "Satochi Node" Jun/2026 0.4v

mv /root/nodenation/satoshi/scripts/*.sh /root/

echo "##### Updating Sistem #####"
sudo apt update && sudo apt upgrade -y

echo "##### Basic Updades and Applications #####"
sudo apt install htop vim net-tools nmap tree lm-sensors openssh-server iptraf-ng iw -y

echo "################################################"
echo "######### Instalação do Bitcoin Core ###########"
echo "################################################"

/root/installcore.sh

echo "##### Aliases #####"
echo '# Now ls be colors.
alias ls="ls -la --color"
# IP detailed
alias ip="ip -c -br -a"
# Otimized Update
alias update="sudo apt update && sudo apt upgrade"
# Checking Ports
alias ports="sudo netstat -tulanp"
# Files Size
alias filesize="du -sh * | sort -h"
# Last prompt
alias gh="history|grep ''"
# ?
alias nf="neofetch"
# cd ..
alias ..="cd .."
#
alias c="clear"
# VIM
alias vi="vim"
# Sudo
alias root="sudo -i"
#
' >> $HOME/.bash_aliases

#echo "###### Updating.... ########"
echo "Execute: source .bashrc"

exit 0
