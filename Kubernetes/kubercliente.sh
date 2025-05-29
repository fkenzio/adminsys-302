#!/bin/bash

# Script para Ubuntu Desktop (cliente)

set -e

echo "Instalando herramientas de cliente Kubernetes..."

# Actualizar sistema
sudo apt update

# Instalar kubectl
echo "Instalando kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Instalar curl y herramientas de red
sudo apt install -y curl wget net-tools

echo "Instalacion completada"
echo
echo "=== COMANDOS PARA CONECTARSE AL SERVIDOR ==="
echo "1. Copiar configuracion desde el servidor:"
echo "   scp usuario@IP_SERVIDOR:~/.kube/config ~/.kube/config"
echo
echo "2. O crear tunel SSH:"
echo "   ssh -L 8080:localhost:8080 usuario@IP_SERVIDOR"
echo "   Luego kubectl port-forward en el servidor"
echo
echo "3. Verificar conexion:"
echo "   kubectl get nodes"
echo "   kubectl get pods"
echo
echo "4. Acceder a la aplicacion:"
echo "   curl http://IP_SERVIDOR:puerto"