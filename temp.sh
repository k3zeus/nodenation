#!/bin/bash
#
# Data e hora
date
#
# Sensores
sensors

paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -s $'\t' -t | sed 's/\(.\)..$/.\1°C/'

# Opção de mostrar em tempo real
#
echo "Mostrar Temperatura em Tempo Real?
#
Deseja continuar? [s/N]"
read resp
if [ $resp. != 's.' ]; then
    exit 0
fi

watch -n 3 -d sensors