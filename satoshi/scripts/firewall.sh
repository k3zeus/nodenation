#!/bin/bash
#
# Verificação do Firewall UFW
#
echo "
######## Regras de portas Liberadas #########
"
ufw show added

echo "
######## Verificando se o Firewall está ativo e suas regras ########
"
ufw status