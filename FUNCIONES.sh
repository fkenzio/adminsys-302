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
