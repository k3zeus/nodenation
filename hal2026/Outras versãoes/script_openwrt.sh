## Script de configuração Halfin Node - v.0.1
# OpenWRT 2025
#
#!/bin/sh
#
# 1. Configurar WAN
uci set network.wan=interface
uci set network.wan.proto='dhcp'
uci set network.wan.ifname='eth0'

# 2. Criar rede ghost
uci set network.ghost=interface
uci set network.ghost.proto='static'
uci set network.ghost.ipaddr='10.21.21.100'
uci set network.ghost.netmask='255.255.255.0'

# 3. Configurar Wi-Fi
uci set wireless.radio0.disabled='0'
uci set wireless.@wifi-iface[0].network='ghost'
uci set wireless.@wifi-iface[0].mode='ap'
uci set wireless.@wifi-iface[0].ssid='ghost'
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='Teste102030'

# 4. Configurar DHCP para ghost
uci set dhcp.ghost=dhcp
uci set dhcp.ghost.interface='ghost'
uci set dhcp.ghost.start='140'
uci set dhcp.ghost.limit='5'
uci set dhcp.ghost.leasetime='12h'
uci set dhcp.ghost.force='1'

# 5. Configurar Firewall

# Criar nova zona para ghost
uci add firewall zone
uci set firewall.@zone[-1].name='ghost_zone'
uci set firewall.@zone[-1].network='ghost'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'

# Encaminhamento ghost -> WAN
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='ghost_zone'
uci set firewall.@forwarding[-1].dest='wan'

# Regra para permitir HTTP
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Ghost-HTTP'
uci set firewall.@rule[-1].src='ghost_zone'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].target='ACCEPT'

# Configurar NAT (Masquerading)
uci add firewall masq
uci set firewall.@masq[-1].src='ghost_zone'
uci set firewall.@masq[-1].outiface='wan'

# 6. Habilitar DNS forwarding
uci set dhcp.ghost.dhcp_list='6,10.21.0.100'

uci commit firewall

# Extra1. Configuração de rotas
# E2. Configure a rota padrão persistentemente
uci set network.wan.gateway="ip route | grep default | awk "{print \$3}""
uci set network.wan.dns='1.1.1.1 8.8.8.8'

# E3. Atualize as zonas do firewall
uci set firewall.@zone[1].network='wan'
uci set firewall.@zone[0].network='lan'
uci set firewall.@forwarding[0].src='lan'
uci set firewall.@forwarding[0].dest='wan'

## Habilite o acesso HTTP
uci set uhttpd.main.listen_http='0.0.0.0:80'
uci commit uhttpd

# 7.0 Reinicie os serviços
/etc/init.d/uhttpd restart
/etc/init.d/firewall restart

# 7.1 Aplicar configurações
uci commit
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

# 7.2 Persistir configurações após reboot
/etc/init.d/firewall enable
/etc/init.d/uhttpd enable
/etc/init.d/dnsmasq enable