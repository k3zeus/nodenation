#!/bin/sh
#
# Script Halfin Install - Ghost Nodes v0.2 19032026
#
    if [ "$EUID" -ne 0 ]; then
        echo "[ERRO] Este script precisa ser executado como root."
        exit 1
    fi
#
# Download do Projeto Completo
wget https://github.com/k3zeus/nodenation/archive/refs/tags/beta_v2.tar.gz && tar -xzvf beta_v2.tar.gz

#
sudo find /home/ -type f -name "*.sh" -print0 | xargs -0 sudo dos2unix

# Permissão de execusão para os scripts
chmod nodenation-beta_v2/hal2026/*.sh

# Pré instalação OrangePi Zero 3
nodenation-beta_v2/hal2026/./pre_install.sh

