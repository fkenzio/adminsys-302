#!/bin/bash
instalar_vsftpd() {
    echo "Instalando vsftpd..."
    sudo apt update
    sudo apt install -y vsftpd
    sudo systemctl enable vsftpd
}
