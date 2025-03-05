#!/bin/bash
agregar_usuario() {
    read -p "Ingrese el nombre del usuario: " usuario
    sudo adduser --disabled-password --gecos "" $usuario
    read -p "Ingrese el grupo (reprobados/recursadores): " grupo
    sudo groupadd -f $grupo
    sudo usermod -aG $grupo $usuario
    sudo mkdir -p /srv/ftp/$usuario /srv/ftp/$grupo
    sudo chown $usuario:$grupo /srv/ftp/$usuario /srv/ftp/$grupo
    sudo chmod 770 /srv/ftp/$usuario /srv/ftp/$grupo
    echo "Usuario $usuario agregado al grupo $grupo."
}
