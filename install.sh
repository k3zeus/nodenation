#!/bin/bash

# Script Halfin Install - Ghost Nodes v0.2 19032026

if [ "$EUID" -ne 0 ]; then
    echo "[ERRO] Este script precisa ser executado como root."
    exit 1
fi

# Download do Projeto Completo
echo "[INFO] Baixando projeto..."
wget https://github.com/k3zeus/nodenation/archive/refs/tags/beta_v2.tar.gz || exit 1
tar -xzvf beta_v2.tar.gz || exit 1

# Converter line endings (se necessário)
echo "[INFO] Convertendo line endings..."
sudo find /home/pleb/ -type f -name "*.sh" -print0 | xargs -0 sudo dos2unix

echo -e  "${CYAN}Changing permition to scripts:${NC} "
echo -e  ""
sudo find /home/pleb/ -name "*.sh" -type f -print0 | xargs -0 sudo chmod +x

# Permissão de execução para os scripts
echo "[INFO] Concedendo permissões..."
chmod +x ./nodenation-beta_v2/hal2026/*.sh || exit 1

# Pré instalação OrangePi Zero 3
echo "[INFO] Iniciando pré-instalação..."
./nodenation-beta_v2/hal2026/pre_install.sh || exit 1

# Fim do script
