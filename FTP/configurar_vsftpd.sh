#!/bin/bash
configurar_vsftpd() {
    echo "Configurando vsftpd..."
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    echo "anonymous_enable=YES" | sudo tee -a /etc/vsftpd.conf
    echo "local_enable=YES" | sudo tee -a /etc/vsftpd.conf
    echo "write_enable=YES" | sudo tee -a /etc/vsftpd.conf
    echo "chroot_local_user=YES" | sudo tee -a /etc/vsftpd.conf
    echo "allow_writeable_chroot=YES" | sudo tee -a /etc/vsftpd.conf
    echo "PasvEnable=YES" | sudo tee -a /etc/vsftpd.conf
    sudo systemctl restart vsftpd
}
