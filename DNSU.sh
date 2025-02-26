#!/bin/bash

DOMINIO="reprobados.com"
IP_SERVIDOR="192.168.0.155"
NAMED_CONF="/etc/bind/named.conf.local"
ZONE_FILE="/etc/bind/db.reprobados"

echo "Instalando bind9..."
sudo apt update && sudo apt install -y bind9 bind9-utils bind9-dnsutils

echo "configurando named.conf.local..."

sudo tee $NAMED_CONF > /dev/null <<EOL
zone "$DOMINIO" {
	type master;
	file "$ZONE_FILE";
};
EOL

echo "Creando archivo de zona..."
sudo tee $ZONA_FILE > /dev/null <<EOL
\$TTL 604800
@	IN	SOA	ns.$DOMINIO. admin.$DOMINIO. (
			2	; Serial
			604800	; Refresh
			86400	; Retry
			2419200 ; Expire
			604800 ); Negative Cache TTL
;
@	IN	SOA	ns.$DOMINIO.
@	IN	A	$IP_SERVIDOR
www	IN	A	$IP_SERVIDOR
ns	IN	A	$IP_SERVIDOR
EOL

echo "Verificando configuracion de bind9"
sudo named-checkconf
sudo named-checkzone $DOMINIO $ZONA_FILE

echo "Reiniciando bind9..."
sudo systemctl restart bind9

echo "Configuracion DNS completada"
echo "Verifica con: nslookup reprobados.com $IP_SERVIDOR"
