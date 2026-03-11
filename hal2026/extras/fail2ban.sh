#!/bin/bash
#
# Script for fail2ban installation
#################### Fail2ban Service ####################
echo " "
echo "####################################################"
echo " ##### Jail Active Service Firewall - Fail2ban #####"
echo "####################################################"
echo " "
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.{conf,local}

cat echo "
[sshd]
enabled = true
port = 22                   # Port SSH
maxretry = 4                   # Block after 4 fails
bantime = 1w                   # block time
" >> /etc/fail2ban/jail.local

sudo systemctl restart fail2ban # Start Service

echo "# Fail2ban is Active #"
echo ""