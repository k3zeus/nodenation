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
if command -v dos2unix >/dev/null 2>&1; then
  find ./nodenation-beta_v2/hal2026/ -type f -name "*.sh" -exec dos2unix {} \; || true
else
  echo "[WARN] dos2unix não encontrado, pulando conversão de line endings"
fi

# Permissão de execução para os scripts
echo "[INFO] Concedendo permissões..."
chmod +x ./nodenation-beta_v2/hal2026/*.sh || exit 1

# Pré instalação OrangePi Zero 3
echo "[INFO] Iniciando pré-instalação..."
./nodenation-beta_v2/hal2026/pre_install.sh || exit 1

# Fim do script
