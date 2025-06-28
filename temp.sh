#!/bin/bash
#
# Script for temperature monitor v.0.1 - @k3zeus
date
#
# Sensores
sensors

paste <(cat /sys/class/thermal/thermal_zone*/type) <(cat /sys/class/thermal/thermal_zone*/temp) | column -s $'\t' -t | sed 's/\(.\)..$/.\1°C/'

# Option to show in real time
#
echo "Show Real Time Temperature?
#
Continue? [y/N]"
read resp
if [ $resp. != 'y.' ]; then
    exit 0
fi

watch -n 3 -d sensors
