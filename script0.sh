#!/bin/sh

echo "##### Atualizando o Sistema #####"
sudo apt update && sudo apt upgrade -y

echo "##### Instalando as Ferramentas Básicas #####"
sudo apt install htop vim net-tools nmap tree lm-sensors openssh-server iptraf-ng -y

echo "##### criando Aliases #####"
echo '# Agora ls é colorido, frufru.
alias ls="ls -la --color"
# IP mais detalhado
alias ip="ip -c -br -a"
# Update simples
alias update="sudo apt update && sudo apt upgrade"
# Verificando Portas
alias ports="sudo netstat -tulanp"
# Mostrando tamanho dos arquvios
alias filesize="du -sh * | sort -h"
# Ultimos comandos
alias gh="history|grep"
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

#echo "###### Atualizando ########"
echo "Execute: source .bashrc"

exit 0