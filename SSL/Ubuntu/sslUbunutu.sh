#!/bin/bash

#######################################
# Función global para abrir un puerto en UFW
#######################################
function habilitar_puerto_firewall() {
    local port=$1
    echo "Habilitando puerto $port en el firewall (UFW)..."
    sudo ufw allow "${port}/tcp"
}

# Función para instalar dependencias necesarias
function instalar_dependencias() {
    echo "Instalando dependencias necesarias..."
    sudo apt update
    sudo apt install -y build-essential wget tar unzip gcc make libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev libapr1-dev libaprutil1-dev default-jdk
    echo "Dependencias instaladas."
}

# Función para obtener versiones de Apache disponibles
function obtener_versiones_apache() {
    echo "httpd-2.4.63.tar.gz"
}

# Función para obtener versiones de Tomcat disponibles
function obtener_versiones_tomcat() {
    echo "apache-tomcat-11.0.5.tar.gz"
    echo "apache-tomcat-10.1.39.tar.gz"
}

# Función para validar el puerto
function validar_puerto() {
    if [[ $1 -lt 1 || $1 -gt 65500 ]]; then
        echo "Error: El puerto ingresado ($1) está fuera del rango permitido (1-65500)."
        return 1
    fi
}

# Función para verificar si Apache está en ejecución en el puerto
function verificar_httpd() {
    local puerto=$1
    if pgrep -x "httpd" >/dev/null; then
        echo "httpd ya está en ejecución."
        # Verifica si está escuchando en el puerto
        if sudo ss -tulnp | grep -q ":$puerto "; then
            echo "httpd está escuchando en el puerto $puerto."
            return 0
        else
            echo "Error: httpd no está escuchando en el puerto $puerto."
            return 1
        fi
    else
        echo "httpd no está en ejecución."
        return 1
    fi
}

function instalar_apache() {
    instalar_dependencias

    apache_install_dir="/opt/apache"
    archivo_descargado="/tmp/apache.tar.gz"

    # Lista de puertos restringidos
    puertos_restringidos=(1 5 7 9 11 13 17 18 19 20 21 22 23 25 29 37 39 42 43 49 50 53 67 68 69 70 79 88 95 101 109 110 115 118 119 123 137 138 139 143 161 162 177 179 194 201 202 204 206 209 220 389 443 445 465 514 515 520 546 547 563 587 591 631 636 853 990 993 995 1194 1337 1701 1723 1813 2049 2082 2083 3074 3306 3389 4489 6667 6881 6969 25565)

    # Función interna para verificar si un puerto está en uso
    function puerto_en_uso() {
        if command -v ss >/dev/null 2>&1; then
            ss -tuln | grep -q ":$1 "
        elif command -v lsof >/dev/null 2>&1; then
            lsof -i :$1 >/dev/null 2>&1
        else
            netstat -tulnp | grep -q ":$1 "
        fi
    }

    # Función interna para generar certificados auto-firmados si no existen
    function generar_certificados() {
        if [ ! -f /etc/ssl/apache/server.crt ] || [ ! -s /etc/ssl/apache/server.crt ]; then
            echo "Generando certificados SSL auto-firmados para Apache..."
            sudo mkdir -p /etc/ssl/apache
            sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/ssl/apache/server.key \
                -out /etc/ssl/apache/server.crt \
                -subj "/CN=localhost"
        fi
    }

    # Función interna para limpiar directivas conflictivas en httpd.conf
    function limpiar_configuracion() {
        # Elimina todas las líneas que comiencen con Listen
        sudo sed -i '/^Listen /d' "$apache_install_dir/conf/httpd.conf"
        # Elimina bloques VirtualHost existentes
        sudo sed -i '/<VirtualHost \*\:[0-9]\+>/,/<\/VirtualHost>/d' "$apache_install_dir/conf/httpd.conf"
        # Elimina cualquier directiva DocumentRoot conflictiva
        sudo sed -i '/^DocumentRoot /d' "$apache_install_dir/conf/httpd.conf"
    }

    # Si Apache ya está instalado, se permite modificar la configuración
    if [ -d "$apache_install_dir" ]; then
        echo "Apache ya está instalado en $apache_install_dir."
        read -p "¿Desea modificar el puerto y protocolo actual? (s/n): " modificar
        if [[ "$modificar" =~ ^[Ss]$ ]]; then
            echo "Seleccione el protocolo a usar:"
            select protocolo in "HTTP" "HTTPS"; do
                if [[ -n "$protocolo" ]]; then
                    break
                fi
            done

            while true; do
                read -p "Ingrese el nuevo puerto para Apache: " puerto
                if [[ "$puerto" =~ ^[0-9]+$ ]] && ((puerto >= 1 && puerto <= 65535)); then
                    if [[ " ${puertos_restringidos[*]} " =~ " $puerto " ]]; then
                        echo "El puerto $puerto está restringido. Elija otro."
                    elif puerto_en_uso "$puerto"; then
                        echo "El puerto $puerto ya está en uso. Elija otro."
                    else
                        break
                    fi
                else
                    echo "Puerto inválido. Ingrese un número entre 1 y 65535."
                fi
            done

            # Limpiar configuraciones previas conflictivas
            limpiar_configuracion

            # Asegurarse de que el directorio DocumentRoot exista
            sudo mkdir -p "$apache_install_dir/htdocs"

            if [[ "$protocolo" == "HTTPS" ]]; then
                generar_certificados
                sudo bash -c "cat >> $apache_install_dir/conf/httpd.conf" <<EOF
LoadModule ssl_module modules/mod_ssl.so
Listen $puerto
<VirtualHost *:$puerto>
    DocumentRoot ${apache_install_dir}/htdocs
    SSLEngine on
    SSLCertificateFile /etc/ssl/apache/server.crt
    SSLCertificateKeyFile /etc/ssl/apache/server.key
</VirtualHost>
EOF
            else
                # Para HTTP, simplemente se añade la directiva Listen
                echo "Listen $puerto" | sudo tee -a "$apache_install_dir/conf/httpd.conf" >/dev/null
            fi

            echo "Puerto y protocolo actualizados. Reiniciando Apache..."
            "$apache_install_dir/bin/apachectl" restart >/dev/null
            sleep 3
            if puerto_en_uso "$puerto"; then
                echo "Apache reiniciado en el puerto $puerto con protocolo $protocolo."
                return
            else
                echo "Error: Apache no se inició correctamente en el nuevo puerto. Revisa los logs."
                exit 1
            fi
        else
            return
        fi
    fi

    # Instalación de Apache (si aún no está instalado)
    echo "Seleccione el protocolo a usar:"
    select protocolo in "HTTP" "HTTPS"; do
        if [[ -n "$protocolo" ]]; then
            break
        fi
    done

    echo "Seleccione la versión de Apache a instalar:"
    versiones_apache=($(obtener_versiones_apache))
    select version in "${versiones_apache[@]}"; do
        if [[ -n "$version" ]]; then
            break
        fi
    done

    while true; do
        read -p "Ingrese el puerto en el que desea configurar Apache: " puerto
        if [[ "$puerto" =~ ^[0-9]+$ ]] && ((puerto >= 1 && puerto <= 65535)); then
            if [[ " ${puertos_restringidos[*]} " =~ " $puerto " ]]; then
                echo "El puerto $puerto está restringido. Elija otro."
            elif puerto_en_uso "$puerto"; then
                echo "El puerto $puerto ya está en uso. Elija otro."
            else
                break
            fi
        else
            echo "Puerto inválido. Ingrese un número entre 1 y 65535."
        fi
    done

    # Asegurarse de que el directorio DocumentRoot exista
    sudo mkdir -p "$apache_install_dir/htdocs"

    url_apache="https://dlcdn.apache.org/httpd/$version"
    if [ ! -f "$archivo_descargado" ]; then
        wget "$url_apache" -O "$archivo_descargado" >/dev/null
    fi
    tar -xzf "$archivo_descargado" -C /tmp >/dev/null
    cd /tmp/httpd-*

    ./configure --prefix="$apache_install_dir" --enable-so --enable-ssl --enable-rewrite >/dev/null
    make -j"$(nproc)" >/dev/null
    sudo make install >/dev/null

    if [[ "$protocolo" == "HTTPS" ]]; then
        generar_certificados
        sudo bash -c "cat >> $apache_install_dir/conf/httpd.conf" <<EOF
LoadModule ssl_module modules/mod_ssl.so
Listen $puerto
<VirtualHost *:$puerto>
    DocumentRoot ${apache_install_dir}/htdocs
    SSLEngine on
    SSLCertificateFile /etc/ssl/apache/server.crt
    SSLCertificateKeyFile /etc/ssl/apache/server.key
</VirtualHost>
EOF
    else
        sudo sed -i "s/^Listen .*/Listen $puerto/" "$apache_install_dir/conf/httpd.conf"
    fi

    echo "ServerName localhost" | sudo tee -a "$apache_install_dir/conf/httpd.conf" >/dev/null

    # Iniciar Apache
    if "$apache_install_dir/bin/httpd" -t >/dev/null; then
        echo "Iniciando Apache..."
        "$apache_install_dir/bin/apachectl" start >/dev/null

        # Creamos un index.html por defecto para no ver 'Index of /'
        sudo bash -c "cat > $apache_install_dir/htdocs/index.html" <<EOF
<html>
<head>
  <title>Página de prueba Apache</title>
</head>
<body>
  <h1>Bienvenido a Apache en el puerto $puerto</h1>
  <p>Certificado SSL autofirmado (si aplica) en /etc/ssl/apache</p>
</body>
</html>
EOF

        if verificar_httpd "$puerto"; then
            echo "Apache instalado en $apache_install_dir y configurado en el puerto $puerto con protocolo $protocolo."
        else
            echo "Error: Apache no se inició correctamente. Revisa los logs en $apache_install_dir/logs/error_log"
            exit 1
        fi
    else
        echo "Error en la configuración de Apache. Revisa el archivo httpd.conf."
        exit 1
    fi

    # Abrir el puerto en el firewall
    habilitar_puerto_firewall "$puerto"
}

# Función para verificar si Tomcat está corriendo y escuchando en el puerto especificado
function verificar_tomcat() {
    local puerto=$1
    if pgrep -f "catalina" >/dev/null; then
        echo "Tomcat está en ejecución."
        if sudo ss -tulnp | grep -qE ":${puerto}(\b|[[:space:]])"; then
            echo "Tomcat está escuchando en el puerto $puerto."
            return 0
        else
            echo "Advertencia: Tomcat está en ejecución, pero no en el puerto $puerto."
            return 1
        fi
    else
        echo "Tomcat no está en ejecución."
        return 1
    fi
}

function instalar_tomcat() {
    echo "🛠 Instalando JDK..."
    sudo apt-get install -y default-jdk >/dev/null

    tomcat_install_dir="/opt/tomcat"
    server_xml="$tomcat_install_dir/conf/server.xml"

    puertos_restringidos=(1 5 7 9 11 13 17 18 19 20 21 22 23 25 29 37 39 42 43 49 50 53 67 68 69 70 79 88 95 101 109 110 115 118 119 123 137 138 139 143 161 162 177 179 194 201 202 204 206 209 220 389 443 445 465 514 515 520 546 547 563 587 591 631 636 853 990 993 995 1194 1337 1701 1723 1813 2049 2082 2083 3074 3306 3389 4489 6667 6881 6969 25565)

    function puerto_en_uso() {
        if command -v ss >/dev/null 2>&1; then
            ss -tuln | grep -q ":$1 "
        elif command -v lsof >/dev/null 2>&1; then
            lsof -i :$1 >/dev/null 2>&1
        else
            netstat -tulnp | grep -q ":$1 "
        fi
    }

    if [[ -d "$tomcat_install_dir" ]]; then
        echo "Tomcat ya está instalado en $tomcat_install_dir."
        while true; do
            read -p "¿Desea modificar el puerto actual? (s/n): " cambiar_puerto
            case $cambiar_puerto in
                [Ss])
                    while true; do
                        read -p "Ingrese el nuevo puerto para Tomcat: " puerto
                        if [[ "$puerto" =~ ^[0-9]+$ ]] && ((puerto >= 1 && puerto <= 65535)); then
                            if [[ " ${puertos_restringidos[*]} " =~ " $puerto " ]]; then
                                echo "El puerto $puerto está restringido. Elija otro."
                            elif puerto_en_uso "$puerto"; then
                                echo "El puerto $puerto ya está en uso. Elija otro."
                            else
                                echo "Cambiando puerto en server.xml..."
                                sudo sed -i -E "s/Connector port=\"[0-9]+\"/Connector port=\"$puerto\"/" "$server_xml"
                                echo "Deteniendo Tomcat..."
                                sudo "$tomcat_install_dir/bin/shutdown.sh"
                                sleep 3
                                echo "Iniciando Tomcat con el nuevo puerto..."
                                sudo "$tomcat_install_dir/bin/startup.sh"
                                echo "Tomcat reiniciado en el puerto $puerto."
                                return
                            fi
                        else
                            echo "Puerto inválido. Ingrese un número entre 1 y 65535."
                        fi
                    done
                    ;;
                [Nn])
                    return
                    ;;
                *)
                    echo "Opción inválida. Responda con 's' o 'n'."
                    ;;
            esac
        done
    fi

    echo "Seleccione la versión de Tomcat a instalar:"
    versiones_tomcat=($(obtener_versiones_tomcat))
    select version in "${versiones_tomcat[@]}"; do
        if [[ -n "$version" ]]; then
            break
        fi
    done

    while true; do
        echo "Seleccione el protocolo para Tomcat:"
        echo "1) SSL (HTTPS)"
        echo "2) HTTP"
        read -p "Ingrese 1 o 2: " opcion_protocolo
        if [[ "$opcion_protocolo" == "1" ]]; then
            protocolo="ssl"
            break
        elif [[ "$opcion_protocolo" == "2" ]]; then
            protocolo="http"
            break
        else
            echo "Opción inválida. Por favor ingrese 1 o 2."
        fi
    done

    while true; do
        read -p "Ingrese el puerto en el que desea configurar Tomcat: " puerto
        if [[ "$puerto" =~ ^[0-9]+$ ]] && ((puerto >= 1 && puerto <= 65535)); then
            if [[ " ${puertos_restringidos[*]} " =~ " $puerto " ]]; then
                echo "El puerto $puerto está restringido. Elija otro."
            elif puerto_en_uso "$puerto"; then
                echo "El puerto $puerto ya está en uso. Elija otro."
            else
                break
            fi
        else
            echo "Puerto inválido. Ingrese un número entre 1 y 65535."
        fi
    done

    version_mayor=$(echo "$version" | cut -d'-' -f3 | cut -d'.' -f1)
    version_completa=$(echo "$version" | cut -d'-' -f3 | cut -d'.' -f1-3)
    url_tomcat="https://dlcdn.apache.org/tomcat/tomcat-${version_mayor}/v${version_completa}/bin/$version"
    archivo_descargado="/tmp/tomcat.tar.gz"

    echo "Descargando Tomcat desde $url_tomcat..."
    if ! wget -q "$url_tomcat" -O "$archivo_descargado"; then
        echo "Error: No se pudo descargar Tomcat. Verifica la URL."
        exit 1
    fi

    if ! tar -tzf "$archivo_descargado" >/dev/null 2>&1; then
        echo "Error: El archivo descargado está corrupto o incompleto."
        exit 1
    fi

    if [[ -d "$tomcat_install_dir" ]]; then
        echo "Eliminando instalación previa de Tomcat..."
        sudo rm -rf "$tomcat_install_dir"
    fi

    sudo mkdir -p "$tomcat_install_dir"
    echo "Extrayendo Tomcat..."
    sudo tar -xzf "$archivo_descargado" -C "$tomcat_install_dir" --strip-components=1

    if [[ "$protocolo" == "ssl" ]]; then
        configurar_ssl "tomcat"
        generar_keystore "tomcat"
        keystore_file="/etc/ssl/tomcat/keystore.p12"
        sudo sed -i "/<Connector port=\"8080\"/,+2d" "$server_xml"
        sudo sed -i "/<\/Service>/i\
<Connector port=\"$puerto\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" SSLEnabled=\"true\">\n\
    <SSLHostConfig>\n\
        <Certificate certificateKeystoreFile=\"$keystore_file\"\n\
                     type=\"RSA\"\n\
                     certificateKeystorePassword=\"1234\" />\n\
    </SSLHostConfig>\n\
</Connector>" "$server_xml"

        echo "Tomcat ahora solo escuchará en HTTPS en el puerto $puerto."
    else
        sudo sed -i -E "s/Connector port=\"[0-9]+\"/Connector port=\"$puerto\"/" "$server_xml"
        echo "Configurado Tomcat para escuchar en HTTP en el puerto $puerto."
    fi

    echo "Dando permisos de ejecución a los scripts de Tomcat..."
    sudo chmod +x "$tomcat_install_dir/bin/"*.sh

    echo "Iniciando Tomcat..."
    sudo "$tomcat_install_dir/bin/startup.sh"

    sleep 5

    if verificar_tomcat "$puerto"; then
        echo "Tomcat instalado en $tomcat_install_dir y configurado en el puerto $puerto."
    else
        echo "Error: Tomcat no se inició correctamente. Revisa los logs en $tomcat_install_dir/logs/catalina.out."
        exit 1
    fi
}

function configurar_ssl() {
    local servicio=$1
    local cert_dir="/etc/ssl/$servicio"
    echo "Generando certificado SSL/TLS autofirmado para $servicio..."
    sudo mkdir -p "$cert_dir"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
         -keyout "$cert_dir/server.key" \
         -out "$cert_dir/server.crt" \
         -subj "/C=US/ST=Example/L=City/O=Company/CN=localhost"
    echo "Certificado generado en: $cert_dir"
}

function generar_keystore() {
    local servicio=$1
    local cert_dir="/etc/ssl/$servicio"
    local keystore_pass="1234"
    local keystore_file="$cert_dir/keystore.p12"
    echo "Convirtiendo certificado SSL a formato PKCS12 para $servicio..."
    sudo openssl pkcs12 -export -in "$cert_dir/server.crt" -inkey "$cert_dir/server.key" \
         -out "$keystore_file" -name tomcat -password pass:$keystore_pass
    sudo chmod 644 "$keystore_file"
    sudo chown root:root "$keystore_file"
    echo "Keystore generado en: $keystore_file"
}

function verificar_nginx() {
    read -p "Ingrese el puerto en el que debe estar escuchando Nginx: " puerto
    if pgrep -x "nginx" >/dev/null; then
        echo "Nginx está en ejecución."
        if sudo ss -tulnp | grep -q ":$puerto "; then
            echo "Nginx está escuchando en el puerto $puerto."
        else
            echo "Advertencia: Nginx está en ejecución, pero no en el puerto $puerto."
        fi
    else
        echo "Nginx no está en ejecución."
    fi
}

function instalar_nginx() {
    echo "Instalando dependencias para Nginx..."
    sudo apt-get update >/dev/null
    sudo apt-get install -y build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev >/dev/null

    nginx_install_dir="/usr/local/nginx"
    nginx_conf="$nginx_install_dir/conf/nginx.conf"

    # Lista de puertos restringidos
    puertos_restringidos=(1 5 7 9 11 13 17 18 19 20 21 22 23 25 29 37 39 42 43 49 50 53 67 68 69 70 79 88 95 101 109 110 115 118 119 123 137 138 139 143 161 162 177 179 194 201 202 204 206 209 220 389 443 445 465 514 515 520 546 547 563 587 591 631 636 853 990 993 995 1194 1337 1701 1723 1813 2049 2082 2083 3074 3306 3389 4489 6667 6881 6969 25565)

    function puerto_en_uso() {
        if command -v ss >/dev/null 2>&1; then
            ss -tuln | grep -q ":$1 "
        elif command -v lsof >/dev/null 2>&1; then
            lsof -i :$1 >/dev/null 2>&1
        else
            netstat -tulnp | grep -q ":$1 "
        fi
    }

    function validar_puerto() {
        local puerto=$1
        if [[ ! "$puerto" =~ ^[0-9]+$ ]] || ((puerto < 1 || puerto > 65535)); then
            echo "Puerto inválido. Ingrese un número entre 1 y 65535."
            return 1
        elif [[ " ${puertos_restringidos[@]} " =~ " $puerto " ]]; then
            echo "El puerto $puerto está **restringido**. Elija otro."
            return 1
        elif puerto_en_uso "$puerto"; then
            echo "El puerto $puerto ya está en uso. Elija otro."
            return 1
        fi
        return 0
    }

    function seleccionar_protocolo() {
        while true; do
            echo "Seleccione el protocolo deseado:"
            echo "1) HTTPS"
            echo "2) HTTP"
            read -p "Opción: " opcion_protocolo
            case $opcion_protocolo in
                1) protocolo="HTTPS"; break ;;
                2) protocolo="HTTP"; break ;;
                *) echo "Opción inválida. Por favor, seleccione 1 o 2." ;;
            esac
        done
    }

    if [[ -d "$nginx_install_dir" ]]; then
        echo "Nginx ya está instalado en $nginx_install_dir."
        while true; do
            read -p "¿Desea modificar el puerto actual? (s/n): " cambiar_puerto
            case $cambiar_puerto in
                [Ss])
                    while true; do
                        read -p "Ingrese el nuevo puerto para Nginx: " puerto
                        if validar_puerto "$puerto"; then
                            if grep -qi "ssl" "$nginx_conf"; then
                                protocolo="HTTPS"
                                if [ ! -f "/etc/ssl/nginx/server.crt" ] || [ ! -f "/etc/ssl/nginx/server.key" ]; then
                                    configurar_ssl "nginx"
                                fi
                                sudo bash -c "cat > $nginx_conf" <<EOF
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
        listen       $puerto ssl;
        server_name  localhost;

        ssl_certificate /etc/ssl/nginx/server.crt;
        ssl_certificate_key /etc/ssl/nginx/server.key;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF
                            else
                                protocolo="HTTP"
                                sudo sed -i "s/listen[[:space:]]\+[0-9]\+;/listen $puerto;/" "$nginx_conf"
                            fi
                            echo "Reiniciando Nginx..."
                            sudo "$nginx_install_dir/sbin/nginx" -s stop >/dev/null
                            sleep 3
                            sudo "$nginx_install_dir/sbin/nginx"
                            sleep 2
                            if puerto_en_uso "$puerto"; then
                                echo "Nginx reiniciado en el puerto $puerto con protocolo $protocolo."
                                return
                            else
                                echo "Error: Nginx no se inició correctamente en el nuevo puerto. Revisa los logs."
                                exit 1
                            fi
                        fi
                    done
                    ;;
                [Nn]) return ;;
                *) echo "Opción inválida. Responda con 's' o 'n'." ;;
            esac
        done
    fi

    echo "Obteniendo versiones disponibles de Nginx..."
    html=$(curl -s "https://nginx.org/en/download.html")
    version_mainline=$(echo "$html" | grep -A5 "Mainline version" | grep -oP 'nginx-\d+\.\d+\.\d+' | head -n1 | sed 's/nginx-//')
    mainline_major_minor=$(echo "$version_mainline" | cut -d '.' -f1,2)
    version_stable=$(echo "$html" | grep -A5 "Stable version" | grep -oP 'nginx-\d+\.\d+\.\d+' | grep -v "${mainline_major_minor}\." | head -n1 | sed 's/nginx-//')

    echo "Seleccione la versión de Nginx a instalar:"
    echo "1) Versión Estable: $version_stable"
    echo "2) Versión Mainline: $version_mainline"
    read -p "Opción: " opcion_version
    case $opcion_version in
        1) version=$version_stable ;;
        2) version=$version_mainline ;;
        *) echo "Opción inválida"; exit 1 ;;
    esac

    seleccionar_protocolo

    while true; do
        read -p "Ingrese el puerto en el que desea configurar Nginx: " puerto
        if validar_puerto "$puerto"; then
            break
        fi
    done

    echo "Descargando e instalando Nginx versión $version..."
    wget -q "https://nginx.org/download/nginx-$version.tar.gz" -O "/tmp/nginx-$version.tar.gz"

    if [[ -d "$nginx_install_dir" ]]; then
        echo "Eliminando instalación previa de Nginx..."
        sudo rm -rf "$nginx_install_dir"
        sudo pkill -f nginx
    fi

    echo "Extrayendo Nginx..."
    tar -xzf "/tmp/nginx-$version.tar.gz" -C /tmp
    cd "/tmp/nginx-$version" || exit 1

    echo "Compilando Nginx..."
    ./configure --prefix="$nginx_install_dir" --with-http_ssl_module >/dev/null
    sudo make -j"$(nproc)" >/dev/null
    sudo make install >/dev/null

    if [[ "$protocolo" == "HTTPS" ]]; then
        if [ ! -f "/etc/ssl/nginx/server.crt" ] || [ ! -f "/etc/ssl/nginx/server.key" ]; then
            configurar_ssl "nginx"
        fi
        sudo bash -c "cat > $nginx_conf" <<EOF
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
        listen       $puerto ssl;
        server_name  localhost;

        ssl_certificate /etc/ssl/nginx/server.crt;
        ssl_certificate_key /etc/ssl/nginx/server.key;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF
    else
        sudo sed -i "s/listen 80;/listen $puerto;/" "$nginx_install_dir/conf/nginx.conf" 2>/dev/null
        sudo sed -i "s/listen       80;/listen       $puerto;/" "$nginx_conf" 2>/dev/null
    fi

    # Creamos un index.html por defecto para no ver 'Index of /'
    sudo bash -c "cat > $nginx_install_dir/html/index.html" <<EOF
<html>
<head>
  <title>Página de prueba Nginx</title>
</head>
<body>
  <h1>Bienvenido a Nginx en el puerto $puerto</h1>
  <p>Certificado SSL autofirmado (si aplica) en /etc/ssl/nginx</p>
</body>
</html>
EOF

    sudo chmod -R 777 "$nginx_install_dir"

    echo "Iniciando Nginx en el puerto $puerto con protocolo $protocolo..."
    sudo "$nginx_install_dir/sbin/nginx" || { echo "Error: Nginx no pudo iniciar."; exit 1; }

    sleep 2

    if puerto_en_uso "$puerto"; then
        echo "Nginx $version instalado y configurado en el puerto $puerto con protocolo $protocolo."
    else
        echo "Error: Nginx no está escuchando en el puerto $puerto. Revisa los logs."
        exit 1
    fi
}

function Mostrar_Menu_Instalacion() {
    while true; do
        echo ""
        echo "====================================="
        echo "     MENÚ DE INSTALACIÓN DE SERVICIOS"
        echo "====================================="
        echo "1) Apache"
        echo "2) Tomcat"
        echo "3) Nginx"
        echo "4) Salir"
        read -p "Opción: " opcion

        case $opcion in
            1)
                instalar_apache
                read -p "Presione Enter para volver al menú..."
                ;;
            2)
                instalar_tomcat
                read -p "Presione Enter para volver al menú..."
                ;;
            3)
                instalar_nginx
                read -p "Presione Enter para volver al menú..."
                ;;
            4)
                echo "Saliendo del script..."
                exit 0
                ;;
            *)
                echo "Opción inválida, intente nuevamente."
                ;;
        esac
    done
}
