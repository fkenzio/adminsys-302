#!/bin/bash

############################################
# Función para validar entrada (solo números)
############################################
validar_opcion() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        return 0
    else
        echo "Entrada inválida. Solo se permiten números."
        return 1
    fi
}

############################################
# Función para validar puerto (1-65535)
############################################
validar_puerto() {
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
        return 0
    else
        echo "Puerto inválido. Debe ser un número entre 1 y 65535."
        return 1
    fi
}

############################################
# Función para verificar si el puerto está reservado
############################################
es_puerto_reservado() {
    local puerto="$1"
    local reserved=(21 22 23 25 53 80 110 135 139 443 445 3306 1433 5432 8080)
    for p in "${reserved[@]}"; do
        if [ "$puerto" -eq "$p" ]; then
            return 0  # Verdadero: está reservado
        fi
    done
    return 1  # Falso: no está reservado
}

############################################
# Función para instalar OpenJDK 11
############################################
instalar_java() {
    echo "Instalando OpenJDK 11..."
    apt update && apt install -y openjdk-11-jdk
    if [ $? -ne 0 ]; then
        echo "Error al instalar OpenJDK 11. Verifica la conexión a internet y vuelve a intentarlo."
        exit 1
    fi
    echo "Configurando JAVA_HOME..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /etc/environment
    source /etc/environment
    echo "JAVA_HOME configurado en: $JAVA_HOME"
}

############################################
# Función para desinstalar/eliminar versión anterior
############################################
desinstalar_servicio() {
    local servicio="$1"
    if [ "$servicio" == "apache2" ]; then
        if dpkg -l | grep -qw apache2; then
            echo "Eliminando instalación anterior de Apache..."
            systemctl stop apache2
            apt purge -y apache2
            apt autoremove -y
            rm -rf /etc/apache2 /var/www/html
        fi
    elif [ "$servicio" == "nginx" ]; then
        if dpkg -l | grep -qw nginx; then
            echo "Eliminando instalación anterior de Nginx..."
            systemctl stop nginx
            apt purge -y nginx
            apt autoremove -y
            rm -rf /etc/nginx /var/www/html
        fi
    elif [ "$servicio" == "tomcat" ]; then
        if systemctl status tomcat &>/dev/null; then
            echo "Eliminando instalación anterior de Tomcat..."
            systemctl stop tomcat
            systemctl disable tomcat
            rm -rf /opt/tomcat
            rm -f /etc/systemd/system/tomcat.service
            systemctl daemon-reload
        fi
    fi
}

############################################
# Función para crear un HTML llamativo para Apache
############################################
crear_html_apache() {
    echo "Creando página web para Apache en /var/www/html/index.html..."
    mkdir -p /var/www/html
    cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>It works</title>
</head>
<body>
  <h1>It works</h1>
</body>
</html>
EOF
}

############################################
# Función para instalar Apache
############################################
instalar_apache() {
    desinstalar_servicio "apache2"
    echo "Selecciona la versión de Apache:"
    echo "1) Apache 2.4.58 (LTS)"
    echo "2) Apache 2.4.1 (Desarrollo)"
    read -p "Elige una opción (1 o 2): " version
    while ! validar_opcion "$version" || [[ "$version" -ne 1 && "$version" -ne 2 ]]; do
        read -p "Opción inválida. Elige 1 o 2: " version
    done
    if [ "$version" == "1" ]; then
        paquete="apache2"
    else
        paquete="apache2=2.4.1"
    fi
    apt update && apt install -y $paquete
    crear_html_apache
    configurar_servicio "apache2"
}

############################################
# Función para instalar Nginx
############################################
instalar_nginx() {
    desinstalar_servicio "nginx"
    echo "Selecciona la versión de Nginx:"
    echo "1) Nginx 1.24 (LTS)"
    echo "2) Nginx 1.25 (Desarrollo)"
    read -p "Elige una opción (1 o 2): " version
    while ! validar_opcion "$version" || [[ "$version" -ne 1 && "$version" -ne 2 ]]; do
        read -p "Opción inválida. Elige 1 o 2: " version
    done
    if [ "$version" == "1" ]; then
        paquete="nginx"
    else
        paquete="nginx=1.25"
    fi
    apt update && apt install -y $paquete
    configurar_servicio "nginx"
}

############################################
# Función para instalar Tomcat
############################################
instalar_tomcat() {
    desinstalar_servicio "tomcat"
    instalar_java
    echo "Selecciona la versión de Tomcat:"
    echo "1) Tomcat 10.1.39 (LTS)"
    echo "2) Tomcat 10.2.3 (Desarrollo)"
    read -p "Elige una opción (1 o 2): " version
    while ! validar_opcion "$version" || [[ "$version" -ne 1 && "$version" -ne 2 ]]; do
        read -p "Opción inválida. Elige 1 o 2: " version
    done
    if [ "$version" == "1" ]; then
        TOMCAT_VERSION="10.1.39"
    else
        TOMCAT_VERSION="10.2.3"
    fi
    echo "Descargando Tomcat versión $TOMCAT_VERSION..."
    wget "https://downloads.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz" -O apache-tomcat.tar.gz
    if [ $? -ne 0 ]; then
        echo "Error al descargar Tomcat. Verifica la URL."
        exit 1
    fi
    tar -xvzf apache-tomcat.tar.gz
    mv apache-tomcat-* /opt/tomcat
    chmod +x /opt/tomcat/bin/*.sh
    echo "Creando archivo de servicio de Tomcat..."
    cat <<EOF | tee /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=root
Group=root
Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable tomcat
    systemctl start tomcat
    configurar_servicio "tomcat"
}

############################################
# Función para solicitar puerto libre
# Se verifica que no esté en uso y que no sea un puerto reservado.
############################################
solicitar_puerto() {
    local puerto
    while true; do
        read -p "Ingrese el puerto para configurar el servicio: " puerto
        if ! validar_puerto "$puerto"; then
            continue
        fi
        if es_puerto_reservado "$puerto"; then
            echo "El puerto $puerto está reservado. Por favor, elija otro puerto."
            continue
        fi
        # Verifica si el puerto está en uso en todos los protocolos
        used=$(ss -lntu | awk '{print $5}' | cut -d: -f2 | grep -w "^$puerto$")
        if [ -n "$used" ]; then
            echo "El puerto $puerto ya está en uso por algún protocolo. Por favor, elija otro puerto."
            continue
        fi
        break
    done
    echo "$puerto"
}

############################################
# Función para configurar el servicio, reglas de firewall y mostrar la URL
############################################
configurar_servicio() {
    puerto=$(solicitar_puerto)
    ufw allow "$puerto"/tcp
    if systemctl list-units --type=service | grep -q "$1"; then
        systemctl enable "$1"
        systemctl restart "$1"
        echo "$1 instalado y configurado en el puerto $puerto"
    else
        echo "El servicio $1 no se encontró. Verifique la instalación de $1."
        exit 1
    fi
    if [ "$1" == "apache2" ]; then
        sed -i "s/Listen 80/Listen $puerto/" /etc/apache2/ports.conf
        sed -i "s/:80/:$puerto/" /etc/apache2/sites-available/000-default.conf
        systemctl restart apache2
        echo "Apache configurado para escuchar en el puerto $puerto"
    elif [ "$1" == "nginx" ]; then
        sed -i "s/listen 80 default_server;/listen $puerto default_server;/" /etc/nginx/sites-available/default
        sed -i "s/listen [::]:80 default_server;/listen [::]:$puerto default_server;/" /etc/nginx/sites-available/default
        systemctl restart nginx
        echo "Nginx configurado para escuchar en el puerto $puerto"
    elif [ "$1" == "tomcat" ]; then
        sed -i "s/port=\"8080\"/port=\"$puerto\"/" /opt/tomcat/conf/server.xml
        systemctl restart tomcat
        echo "Tomcat configurado para escuchar en el puerto $puerto"
    fi
    IP=$(hostname -I | awk '{print $1}')
    echo "El servicio $1 está disponible en: http://$IP:$puerto"
}

############################################
# Menú principal cíclico
############################################
while true; do
    echo "¿Qué servicio desea instalar?"
    echo "1) Apache"
    echo "2) Tomcat"
    echo "3) Nginx"
    echo "4) Salir"
    read -p "Seleccione una opción (1-4): " opcion
    while ! validar_opcion "$opcion" || [[ "$opcion" -lt 1 || "$opcion" -gt 4 ]]; do
        read -p "Opción inválida. Seleccione una opción válida (1-4): " opcion
    done
    case "$opcion" in
        1) instalar_apache ;;
        2) instalar_tomcat ;;
        3) instalar_nginx ;;
        4) echo "Saliendo del script."; exit 0 ;;
    esac
    echo "----------------------------------------"
    echo "Regresando al menú principal..."
    echo "----------------------------------------"
done
