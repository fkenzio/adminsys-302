#!/bin/bash

# Función para validar una dirección IP
validar_ip() {
    local ip=$1
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octetos <<< "$ip"
        for octeto in "${octetos[@]}"; do
            if ((octeto < 0 || octeto > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Función para solicitar datos al usuario
solicitar_datos() {
    read -p "Por favor, ingresa el dominio: " DOMINIO

    while true; do
        read -p "Por favor, ingresa la dirección IP del servidor DNS: " IP_SERVIDOR
        if validar_ip "$IP_SERVIDOR"; then
            break
        else
            echo "La dirección IP ingresada no es válida. Intenta nuevamente."
        fi
    done
}

validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                echo "IP inválida: fuera de rango"
                exit 1
            fi
        done
    else
        echo "Formato de IP inválido"
        exit 1
    fi
}

configure_network() {
    local server_ip=$1
    IFS='.' read -r o1 o2 o3 o4 <<< "$server_ip"
    local subnet_ip="$o1.$o2.$o3.0"
    local gateway_ip="$o1.$o2.$o3.1"
    
    echo "Subred detectada: $subnet_ip"
    echo "Puerta de enlace configurada en: $gateway_ip"
    
    echo "network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      addresses: [$server_ip/24]
      gateway4: $gateway_ip
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
    
    echo "Fijando la IP $server_ip con puerta de enlace $gateway_ip"
    sudo netplan apply
    echo "Aplicando cambios"
}

configure_dhcp_server() {
    local subnet_ip=$1
    local gateway_ip=$2
    local range_start=$3
    local range_end=$4
    
    echo "INTERFACESv4=\"enp0s3\"" | sudo tee /etc/default/isc-dhcp-server > /dev/null
    
    cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf > /dev/null
default-lease-time 600;
max-lease-time 7200;
subnet $subnet_ip netmask 255.255.255.0 {
    range ${range_start} ${range_end};
    option routers $gateway_ip;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF
}


