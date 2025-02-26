#!/bin/bash
echo "voy actualizar el sistema"
sudo apt update && sudo apt update -y

echo "estou instalando el openssh"
sudo apt install -y openssh-server

echo "iniciando y habilitando el ssh"
sudo systemctl start ssh
sudo systemctl enable ssh

echo "configurando el firewall para el ssh"
sudo ufw allow ssh
sudo ufw reload

echo "verificando el estado del servicio ssh"
sudo systemctl status ssh --no-pager

echo "todo perfecto ya esta corriendo con toño la mmomia"
