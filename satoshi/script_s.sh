#!/bin/sh
#
# Instalation Configuration and Tools for "Satochi Node" Jun/2026 0.4v

mv /$HOME/nodenation/satoshi/scripts/*.sh /$HOME/nodenation/

echo "##### Updating Sistem #####"
sudo apt update && sudo apt upgrade -y

echo "##### Basic Updades and Applications #####"
sudo apt install htop vim net-tools nmap tree lm-sensors openssh-server iptraf-ng -y

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