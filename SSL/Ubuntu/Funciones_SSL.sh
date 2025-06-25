#!/bin/bash

# Función para instalar OpenSSL
install_opnessl(){
    sudo apt update & sudo apt install openssl
}

configurar_ssl_vsftpd() {
    local cert_path="/etc/ssl/certs/vsftpd.crt"
    local key_path="/etc/ssl/private/vsftpd.key"

    echo "Generando certificado SSL para vsftpd..."

    # Crear el certificado y la clave privada
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_path" \
        -out "$cert_path" \
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=MyCompany/CN=ftp.example.com"

    # Ajustar permisos
    sudo chmod 600 "$key_path"
    sudo chmod 644 "$cert_path"

    echo "Certificado SSL generado en:"
    echo " - Certificado: $cert_path"
    echo " - Clave privada: $key_path"

    echo "Reiniciando vsftpd..."
    sudo systemctl restart vsftpd

    echo "Proceso completado. Verifique que vsftpd esté funcionando con SSL."
}

# Función para configurar el archivo vsftpd.conf
config_vsftpd() {

    local rootCertificate="/etc/ssl/certs/vsftpd.crt"
    local rootPrivateKey="/etc/ssl/private/vsftpd.key"
    # Hacer un respaldo de la configuración original
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    # Escribir nueva configuración en vsftpd.conf
    sudo tee /etc/vsftpd.conf > /dev/null <<EOF
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
chroot_local_user=NO
allow_writeable_chroot=YES
anon_world_readable_only=NO
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES

# Configuración SSL
ssl_enable=YES
allow_anon_ssl=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
rsa_cert_file=$rootCertificate
rsa_private_key_file=$rootPrivateKey

# Configuración de puertos
listen_port=990
implicit_ssl=YES
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF

    # Reinicio el servicio FTP
    sudo systemctl restart vsftpd
    sudo systemctl enable vsftpd
}

# Instalar servicio http con SSL
install_server_http_ssl() {
    local url=$1
    local versionInstall=$2
    local archivoDescomprimido=$3
    local servicio=$4

    # Instalar la version
    if ! curl -s -O "$url$versionInstall"; then
        echo "Error al descargar el archivo $versionInstall"
        return 1
    fi
    
    # Descomprimir el archivo descargado
    sudo tar -xzf $versionInstall > /dev/null 2>&1
    
    # Entrar a la carpeta
    cd "$archivoDescomprimido"
    
    # Instalar dependencias para SSL
    sudo apt install -y libssl-dev > /dev/null 2>&1
    
    # Configurar según el tipo de servidor
    if [ "$servicio" = "apache2" ]; then
        # Compilar Apache con soporte SSL
        ./configure --prefix=/usr/local/"$servicio" --enable-ssl --enable-so > /dev/null 2>&1
    elif [ "$servicio" = "nginx" ]; then
        # Compilar Nginx con soporte SSL
        ./configure --prefix=/usr/local/"$servicio" \
            --with-http_ssl_module \
            --with-http_v2_module > /dev/null 2>&1
    else
        echo "Tipo de servidor no soportado"
        return 1
    fi
    
    # Instalar servicio
    make -s > /dev/null 2>&1
    sudo make install > /dev/null 2>&1
}

# Función para generar certificados SSL
generate_ssl_cert() {
    local cert_dir=$1
    
    # Crear directorios para certificados si no existen
    sudo mkdir -p $cert_dir
    
    # Generar certificado autofirmado
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout $cert_dir/server.key \
        -out $cert_dir/server.crt \
        -subj "/C=ES/ST=State/L=City/O=Organization/CN=localhost" \
        > /dev/null 2>&1
        
    echo "Certificado SSL autofirmado generado en $cert_dir"
}

generate_ssl_cert_tomcat(){
    local cert_dir=$1
    local keystore_pass="changeit"

    # Crear directorios para certificados si no existen
    sudo mkdir -p "$cert_dir"

    # Generar clave privada y certificado autofirmado
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/server.key" \
        -out "$cert_dir/server.crt" \
        -subj "/C=ES/ST=State/L=City/O=Organization/CN=localhost" \
        > /dev/null 2>&1

    echo "Certificado SSL generado en $cert_dir"

    # Convertir el certificado y clave en un archivo PKCS12
    sudo openssl pkcs12 -export -in "$cert_dir/server.crt" -inkey "$cert_dir/server.key" \
        -out "$cert_dir/keystore.p12" -name tomcat -password pass:$keystore_pass \
        > /dev/null 2>&1

    # Convertir PKCS12 a Keystore JKS (formato requerido por Tomcat)
    sudo keytool -importkeystore -destkeystore "$cert_dir/keystore.jks" \
        -srckeystore "$cert_dir/keystore.p12" -srcstoretype PKCS12 \
        -alias tomcat -deststorepass $keystore_pass -srcstorepass $keystore_pass \
        > /dev/null 2>&1

    echo "Keystore generado en $cert_dir/keystore.jks"
}

# Función para configurar SSL en Apache
configure_ssl_apache() {
    local apache_root=$1
    local port=$2
    local https_port=$3
    
    # Ruta para certificados
    local cert_dir="$apache_root/conf/ssl"
    
    # Generar certificados
    generate_ssl_cert "$cert_dir"
    
    # Habilitar módulos SSL en httpd.conf
    sudo sed -i 's/#LoadModule ssl_module modules\/mod_ssl.so/LoadModule ssl_module modules\/mod_ssl.so/' $apache_root/conf/httpd.conf
    sudo sed -i 's/#LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so/LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so/' $apache_root/conf/httpd.conf
    
    # Configurar puerto HTTP
    sudo sed -i '/^Listen/d' $apache_root/conf/httpd.conf
    sudo printf "Listen $port\n" >> $apache_root/conf/httpd.conf
    
    # Añadir configuración SSL al final del archivo
    cat << EOF | sudo tee -a $apache_root/conf/httpd.conf > /dev/null
# SSL Configuration
Listen $https_port
<VirtualHost *:$https_port>
    DocumentRoot "$apache_root/htdocs"
    SSLEngine on
    SSLCertificateFile "$cert_dir/server.crt"
    SSLCertificateKeyFile "$cert_dir/server.key"
    <Directory "$apache_root/htdocs">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
    
    echo "SSL configurado correctamente para Apache"
}

# Función para configurar SSL en Nginx
configure_ssl_nginx() {
    local nginx_root=$1
    local http_port=$2
    local https_port=$3
    
    # Ruta para certificados
    local cert_dir="$nginx_root/conf/ssl"
    
    # Generar certificados
    generate_ssl_cert "$cert_dir"
    
    # Crear configuración de Nginx con SSL
    cat << EOF | sudo tee $nginx_root/conf/nginx.conf > /dev/null
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       $http_port;
        server_name  localhost;
        
        location / {
            root   html;
            index  index.html index.htm;
        }
        
        # Redirigir HTTP a HTTPS (opcional)
        # return 301 https://\$host:\$server_port\$request_uri;
    }

    server {
        listen       $https_port ssl;
        server_name  localhost;

        ssl_certificate      $cert_dir/server.crt;
        ssl_certificate_key  $cert_dir/server.key;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
EOF
    
    echo "SSL configurado correctamente para Nginx"
    
    # Reiniciar Nginx para aplicar cambios
    sudo $nginx_root/sbin/nginx -s reload || sudo $nginx_root/sbin/nginx
}