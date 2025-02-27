#!/bin/bash

sudo apt-get install -y isc-dhcp-server
echo "ISC DHCP se instaló correctamente"

source C:\Users\Victor Ruiz\OneDrive\Documentos\GitHub\adminsys-302\FUNCIONES.sh

read -p "Ingresa la IP del servidor DHCP: " SERVER_IP
validate_ip "$SERVER_IP"

configure_network

configure_dhcp_server

sudo systemctl daemon-reload
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

echo "Servidor DHCP ejecutándose con rango $RANGE_START - $RANGE_END en la subred $SUBNET_IP."