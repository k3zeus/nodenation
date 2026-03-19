#!/bin/bash
#
# Script para criação de regras IPtables para Halfin Node- v.0.1 (IP Forward)
#

# Verificação de root
if [[ $EUID -ne 0 ]]; then
  echo "Este script deve ser executado como root."
  exit 1
fi

echo "⚙️  Configurando iptables para permitir apenas SSH..."


echo ""
echo "#############################################"
echo "######## Criação das regras Firewall ########"
echo "#############################################"
echo ""

echo 1 > /proc/sys/net/ipv4/ip_forward

# Detectar interface WAN (se necessário)
WAN_IFACE=$(ip route | grep default | awk '{print $5}')

#sudo iptables -t nat -F
#sudo iptables -F

# Política padrão: negar tudo
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

sudo iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
sudo iptables -A FORWARD -i "$WAN_IFACE" -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i br0 -o "$WAN_IFACE" -j ACCEPT

# Permitir conexões já estabelecidas (respostas às saídas)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permitir tráfego na interface de loopback (localhost)
iptables -A INPUT -i lo -j ACCEPT

# Permitir conexões SSH (porta 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

echo "✅ Regras aplicadas: apenas SSH permitido na entrada."

############
# Salvar regras para persistência
sudo iptables-save > /etc/iptables.rules

# Criar script de restauração em boot
cat <<EOF | sudo tee /etc/network/if-up.d/iptables

iptables-restore < /etc/iptables.rules
EOF

sudo chmod +x /etc/network/if-up.d/iptables

netfilter-persistent save