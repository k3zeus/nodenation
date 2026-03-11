#!/bin/bash
#
# Script para Monitoramento em tempo real e log Halfin Node- v.0.1
#
echo -e "\n#######################################"
echo "[1] Monitorar Conexões em Tempo Real"
echo "[2] Gerar Relatório completo"
echo -e "####################################### \n"

read -p "Escolha a opção [1 ou 2]: " escolha

case $escolha in

1)
echo "
####### Mostrar Conexões Ativas #######
"
watch -n 2 "sudo ss -ptu -H -o | awk '{print \$6 \" ? \" \$1}' | sort | uniq -c"
;;

2)

echo "
###### Mostrar Conexões SSH ######
"
cat /var/log/auth.log | grep --line-buffered 'password'

echo "
###############################################
"

echo "
####### Monitorar Portas Ativas #########
"
#watch -n 5 ""
ss -tulwnH #| awk '{print \$5}' | cut -d':' -f2 | sort | uniq

echo "
--- CONEXÕES ATIVAS ---
"
sudo ss -ptu -H -o  | awk '{print $6 " ? " $1}'

echo -e "\n--- TENTATIVAS SSH HOJE ---"
sudo grep "sshd" /var/log/auth.log | grep "Failed password"

echo -e "\n--- ALERTAS FAIL2BAN ---"
sudo fail2ban-client status sshd
exit 0
;;

esac