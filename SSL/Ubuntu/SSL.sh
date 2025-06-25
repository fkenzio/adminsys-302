#!/bin/bash

source Funciones_SSL.sh
source Funciones_HTTP.sh

# install_opnessl
configurar_ssl_vsftpd
config_vsftpd
ftp_url="ftps://localhost"

OPCION=-1

while [ "$OPCION" -ne 0 ]; do
    echo "¿Donde desea instalar el servicio HTTP?"
    echo "1. Desde FTP."
    echo "2. Desde la Web."
    echo "0. Salir."
    read -p "Eliga una opción: " OPCION

    case "$OPCION" in
        # Opción de instalación por FTP
        1)
            read -p "¿Deseas usar una conexión segura (SSL) para FTP? (si/no) " OPCION_SSL

            case "$OPCION_SSL" in
                "si")
                    echo "Conectandose al servidor FTPS..."
                    OPCION_FTP=""
                    while [ "$OPCION_FTP" != "salir" ]; do
                    
                        echo "Menú de instalación en FTP"
                        echo "Servicios HTTP disponibles:"
                        curl --ftp-ssl -k $ftp_url/http/ubuntu/
                        read -p "Elija un servicio 'apache' 'tomcat' 'nginx': " OPCION_FTP

                        case "$OPCION_FTP" in
                            "apache")
                                echo "Instalar Apache desde FTP..."
                                curl -k $ftp_url/http/ubuntu/Apache/
                                downloadsApache="https://downloads.apache.org/httpd/"
                                page_apache=$(get_html "$downloadsApache")
                                mapfile -t versions < <(get_lts_version "$downloadsApache" 0)
                                last_lts_version=${versions[0]}

                                echo "¿Que versión de apache desea instalar"
                                echo "1. Versión LTS disponible en el servidor FTP $last_lts_version"
                                echo "2. Versión de desarrollo disponible en el servidor FTP."
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_APACHE

                                case "$OPCION_APACHE" in
                                    1)
                                        # Pedir los puertos al usuario
                                        read -p "Ingrese el puerto en el que se instalará Apache: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        # Verificar si los puertos están disponibles
                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            curl -k -o httpd-$last_lts_version.tar.gz $ftp_url/http/ubuntu/Apache/httpd-$last_lts_version.tar.gz
                                            # Descomprimir el archivo
                                            sudo tar -xvzf httpd-$last_lts_version.tar.gz > /dev/null 2>&1
                                            # Entrar a la carpeta descomprimida
                                            cd /home/luissoto11/"httpd-$last_lts_version"
                                            # Compilar Apache con soporte SSL
                                            ./configure --prefix=/usr/local/"apache2" --enable-ssl --enable-so > /dev/null 2>&1
                                            # Instalar el servicio
                                            make > /dev/null 2>&1
                                            sudo make install > /dev/null 2>&1
                                            # Verificar la instalacón
                                            /usr/local/apache2/bin/httpd -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/apache2"
                                            configure_ssl_apache "$routeFileConfiguration" "$PORT" "$HTTPS_PORT"
                                            sudo /usr/local/apache2/bin/apachectl restart
                                            echo "Configuracion lista"
                                        fi
                                    ;;
                                    2)
                                        echo "Apache no cuenta con versión de desarrollo."
                                    ;;
                                    0)
                                        echo "Saliendo al menú principal..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            "tomcat")
                                echo "Instalar Tomcat desde FTP..."
                                curl -k $ftp_url/http/ubuntu/Tomcat/
                                downloadsTomcat="https://tomcat.apache.org/index.html"
                                dev_version=$(get_lts_version "$downloadsTomcat" 0)
                                last_lts_version=$(get_lts_version "$downloadsTomcat" 1)

                                echo "¿Que versión de Tomcat desea instalar"
                                echo "1. Versión LTS disponible en el servidor FTP $last_lts_version"
                                echo "2. Versión disponible en el servidor FTP $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_TOMCAT

                                case "$OPCION_TOMCAT" in
                                    1)
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 8443):" HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -k -o apache-tomcat-$last_lts_version.tar.gz $ftp_url/http/ubuntu/Tomcat/apache-tomcat-$last_lts_version.tar.gz
                                            tar -xzvf apache-tomcat-$last_lts_version.tar.gz
                                            sudo mv apache-tomcat-$last_lts_version /opt/tomcat

                                            # Generar el certificado SSL y keystore
                                            CERT_DIR="/opt/tomcat/conf"
                                            generate_ssl_cert_tomcat "$CERT_DIR"
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            KEYSTORE_PATH="conf/keystore.jks"
                                            KEYSTORE_PASS="changeit"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"

                                            # Agregar el conector HTTPS si no está presente
                                            if ! grep -q "Connector port=\"$HTTPS_PORT\"" "$server_xml"; then
                                                sudo sed -i "/<\/Service>/i \
                                                <Connector port=\"$HTTPS_PORT\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" \n\
                                                        maxThreads=\"200\" SSLEnabled=\"true\"> \n\
                                                    <SSLHostConfig> \n\
                                                        <Certificate certificateKeystoreFile=\"$KEYSTORE_PATH\" \n\
                                                                    type=\"RSA\" \n\
                                                                    certificateKeystorePassword=\"$KEYSTORE_PASS\"/> \n\
                                                    </SSLHostConfig> \n\
                                                </Connector>" "$server_xml"
                                            fi
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    2)
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 8443):" HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -k -o apache-tomcat-$dev_version.tar.gz $ftp_url/http/ubuntu/Tomcat/apache-tomcat-$dev_version.tar.gz
                                            tar -xzvf apache-tomcat-$dev_version.tar.gz
                                            sudo mv apache-tomcat-$dev_version /opt/tomcat

                                            # Generar el certificado SSL y keystore
                                            CERT_DIR="/opt/tomcat/conf"
                                            generate_ssl_cert_tomcat "$CERT_DIR"
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            KEYSTORE_PATH="conf/keystore.jks"
                                            KEYSTORE_PASS="changeit"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"

                                            # Agregar el conector HTTPS si no está presente
                                            if ! grep -q "Connector port=\"$HTTPS_PORT\"" "$server_xml"; then
                                                sudo sed -i "/<\/Service>/i \
                                                <Connector port=\"$HTTPS_PORT\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" \n\
                                                        maxThreads=\"200\" SSLEnabled=\"true\"> \n\
                                                    <SSLHostConfig> \n\
                                                        <Certificate certificateKeystoreFile=\"$KEYSTORE_PATH\" \n\
                                                                    type=\"RSA\" \n\
                                                                    certificateKeystorePassword=\"$KEYSTORE_PASS\"/> \n\
                                                    </SSLHostConfig> \n\
                                                </Connector>" "$server_xml"
                                            fi
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo al menú..."
                                    ;;
                                    *)
                                        echo "Opción no válida"
                                    ;;
                                esac
                            ;;
                            "nginx")
                                echo "Instalar Nginx desde FTP..."
                                curl -k $ftp_url/http/ubuntu/Nginx/
                                downloadsNginx="https://nginx.org/en/download.html"
                                dev_version=$(get_lts_version "$downloadsNginx" 0)
                                last_lts_version=$(get_lts_version "$downloadsNginx" 1)

                                echo "¿Que versión de nginx desea instalar"
                                echo "1. Versión LTS disponible en el servidor FTP $last_lts_version"
                                echo "2. Versión de desarrollo disponible en el servidor FTP $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_NGINX

                                case "$OPCION_NGINX" in
                                    1)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            curl -k -o nginx-$last_lts_version.tar.gz $ftp_url/http/ubuntu/Nginx/nginx-$last_lts_version.tar.gz
                                            # Descomprimir el archivo
                                            sudo tar -xvzf nginx-$last_lts_version.tar.gz > /dev/null 2>&1
                                            # Entrar a la carpeta descomprimida
                                            cd /home/luissoto11/"nginx-$last_lts_version"
                                            # Compilar Nginx con soporte SSL
                                            ./configure --prefix=/usr/local/"nginx" \
                                                --with-http_ssl_module \
                                                --with-http_v2_module > /dev/null 2>&1
                                            # Instalar el servicio
                                            make > /dev/null 2>&1
                                            sudo make install > /dev/null 2>&1
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx"
                                            configure_ssl_nginx "$routeFileConfiguration" "$PORT" "$HTTPS_PORT"
                                            ps aux | grep nginx
                                            echo "Configuracion lista"
                                        fi
                                    ;;
                                    2)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            curl -k -o nginx-$dev_version.tar.gz $ftp_url/http/ubuntu/Nginx/nginx-$dev_version.tar.gz
                                            # Descomprimir el archivo
                                            sudo tar -xvzf nginx-$dev_version.tar.gz > /dev/null 2>&1
                                            # Entrar a la carpeta descomprimida
                                            cd /home/luissoto11/"nginx-$dev_version"
                                            # Compilar Nginx con soporte SSL
                                            ./configure --prefix=/usr/local/"nginx" \
                                                --with-http_ssl_module \
                                                --with-http_v2_module > /dev/null 2>&1
                                            # Instalar el servicio
                                            make > /dev/null 2>&1
                                            sudo make install > /dev/null 2>&1
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx"
                                            configure_ssl_nginx "$routeFileConfiguration" "$PORT" "$HTTPS_PORT"
                                            ps aux | grep nginx
                                            echo "Configuracion lista"
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo al menú..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            *)
                                echo "Opción no válida, debe ingresar el nombre de un servicio o escribir 'salir'."
                            ;;
                        esac
                    done
                ;;
                "no")
                    echo "Conectandose al servidor FTP..."
                    echo "Conectandose al servidor FTPS..."
                    OPCION_FTP=""
                    while [ "$OPCION_FTP" != "salir" ]; do
                        echo "Menú de instalación en FTP"
                        echo "Servicios HTTP disponibles:"
                        curl --ftp-ssl -k $ftp_url/http/ubuntu/
                        read -p "Elija un servicio 'apache' 'tomcat' 'nginx': " OPCION_FTP

                        case "$OPCION_FTP" in
                            "apache")
                                echo "Instalar Apache desde FTP..."
                                curl -k $ftp_url/http/ubuntu/Apache/
                                downloadsApache="https://downloads.apache.org/httpd/"
                                page_apache=$(get_html "$downloadsApache")
                                mapfile -t versions < <(get_lts_version "$downloadsApache" 0)
                                last_lts_version=${versions[0]}

                                echo "¿Que versión de apache desea instalar"
                                echo "1. Versión LTS disponible en el servidor FTP $last_lts_version"
                                echo "2. Versión de desarrollo disponible en el servidor FTP."
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_APACHE

                                case "$OPCION_APACHE" in
                                    1)
                                        # Pedir el puerto al usuario
                                        read -p "Ingrese el puerto en el que se instalará Apache: " PORT
                                        verificar_puerto_reservado -puerto $PORT

                                        # Verificar si el puerto están disponibles
                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        else
                                            curl -k -o httpd-$last_lts_version.tar.gz $ftp_url/http/ubuntu/Apache/httpd-$last_lts_version.tar.gz
                                            # Descomprimir el archivo
                                            sudo tar -xvzf httpd-$last_lts_version.tar.gz > /dev/null 2>&1
                                            # Entrar a la carpeta descomprimida
                                            cd /home/luissoto11/"httpd-$last_lts_version"
                                            # Compilar el archivo
                                            ./configure --prefix=/usr/local/"apache2" > /dev/null 2>&1
                                            # Instalar servicio
                                            make -s > /dev/null 2>&1
                                            sudo make install > /dev/null 2>&1
                                            # Verificar la instalacón
                                            /usr/local/apache2/bin/httpd -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/apache2/conf/httpd.conf"
                                            # Remover el puerto en uso actual
                                            sudo sed -i '/^Listen/d' $routeFileConfiguration
                                            # Añadir puerto que eligio el usuario
                                            sudo printf "Listen $PORT" >> $routeFileConfiguration
                                            # Comprobar si el puerto esta escuchando
                                            sudo grep -i "Listen $PORT" $routeFileConfiguration
                                            sudo /usr/local/apache2/bin/apachectl restart
                                    ;;
                                    2)
                                        echo "Apache no cuenta con versión de desarrollo."
                                    ;;
                                    0)
                                        echo "Saliendo al menú..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            "tomcat")
                                # Instalar tomcat sin SSL desde el FTP
                                echo "Instalar Tomcat desde FTP..."
                                curl -k $ftp_url/http/ubuntu/Tomcat/
                                downloadsTomcat="https://tomcat.apache.org/index.html"
                                dev_version=$(get_lts_version "$downloadsTomcat" 0)
                                last_lts_version=$(get_lts_version "$downloadsTomcat" 1)

                                echo "¿Que versión de Tomcat desea instalar"
                                echo "1. Versión LTS disponible en el servidor FTP $last_lts_version"
                                echo "2. Versión disponible en el servidor FTP $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_TOMCAT

                                case "$OPCION_TOMCAT" in
                                    1)
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 8443):" HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -k -o apache-tomcat-$last_lts_version.tar.gz $ftp_url/http/ubuntu/Tomcat/apache-tomcat-$last_lts_version.tar.gz
                                            tar -xzvf apache-tomcat-$last_lts_version.tar.gz
                                            sudo mv apache-tomcat-$last_lts_version /opt/tomcat
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    2)
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 8443):" HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -k -o apache-tomcat-$dev_version.tar.gz $ftp_url/http/ubuntu/Tomcat/apache-tomcat-$dev_version.tar.gz
                                            tar -xzvf apache-tomcat-$dev_version.tar.gz
                                            sudo mv apache-tomcat-$dev_version /opt/tomcat
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo al menú..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            "nginx")
                                # Instalar nginx sin SSL desde el FTP
                                echo "Instalar Nginx desde FTP..."
                                curl -k $ftp_url/http/ubuntu/Nginx/
                                downloadsNginx="https://nginx.org/en/download.html"
                                dev_version=$(get_lts_version "$downloadsNginx" 0)
                                last_lts_version=$(get_lts_version "$downloadsNginx" 1)

                                echo "¿Que versión de nginx desea instalar"
                                echo "1. Versión LTS disponible en el servidor FTP $last_lts_version"
                                echo "2. Versión de desarrollo disponible en el servidor FTP $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_NGINX

                                case "$OPCION_NGINX" in
                                    1)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            curl -k -o nginx-$last_lts_version.tar.gz $ftp_url/http/ubuntu/Nginx/nginx-$last_lts_version.tar.gz
                                            # Descomprimir el archivo
                                            sudo tar -xvzf nginx-$last_lts_version.tar.gz > /dev/null 2>&1
                                            # Entrar a la carpeta descomprimida
                                            cd /home/luissoto11/"nginx-$last_lts_version"
                                            # Compilar el archivo
                                            ./configure --prefix=/usr/local/"nginx" > /dev/null 2>&1
                                            # Instalar el servicio
                                            make > /dev/null 2>&1
                                            sudo make install > /dev/null 2>&1
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx/conf/nginx.conf"
                                            # Modificar el puerto
                                            sed -i -E "s/listen[[:space:]]{7}[0-9]{1,5}/listen      $PORT/" "$routeFileConfiguration"
                                            # Verificar si esta escuchando en el puerto
                                            sudo grep -i "listen[[:space:]]{7}" "$routeFileConfiguration"
                                            sudo /usr/local/nginx/sbin/nginx
                                            sudo /usr/local/nginx/sbin/nginx -s reload
                                            ps aux | grep nginx
                                        fi
                                    ;;
                                    2)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            curl -k -o nginx-$dev_version.tar.gz $ftp_url/http/ubuntu/Nginx/nginx-$dev_version.tar.gz
                                            # Descomprimir el archivo
                                            sudo tar -xvzf nginx-$dev_version.tar.gz > /dev/null 2>&1
                                            # Entrar a la carpeta descomprimida
                                            cd /home/luissoto11/"nginx-$dev_version"
                                            # Compilar el archivo
                                            ./configure --prefix=/usr/local/"nginx" > /dev/null 2>&1
                                            # Instalar el servicio
                                            make > /dev/null 2>&1
                                            sudo make install > /dev/null 2>&1
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx/conf/nginx.conf"
                                            # Modificar el puerto
                                            sed -i -E "s/listen[[:space:]]{7}[0-9]{1,5}/listen      $PORT/" "$routeFileConfiguration"
                                            # Verificar si esta escuchando en el puerto
                                            sudo grep -i "listen[[:space:]]{7}" "$routeFileConfiguration"
                                            sudo /usr/local/nginx/sbin/nginx
                                            sudo /usr/local/nginx/sbin/nginx -s reload
                                            ps aux | grep nginx
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo al menú..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            "salir")
                                echo "Saliendo..."
                            ;;
                            *)
                                echo "Opción no válida."
                            ;;
                        esac
                    done
                ;;
                *)
                    echo "Opción inválida (SI/NO)"
                ;;
            esac
        ;;
        # Opción de instalación por la Web
        2)
            read -p "¿Deseas incluir SSL en la configuración del servicio HTTP? (si/no) " OPCION_SSL

            case "$OPCION_SSL" in
                "si")
                    echo "Instalar el servicio HTTP con SSL..."
                    OPCION_HTTP=-1
                    while [ "$OPCION_HTTP" -ne 0 ]; do
                        echo "¿Qué servicio desea instalar?"
                        echo "1. Apache."
                        echo "2. Tomcat."
                        echo "3. Nginx."
                        echo "0. Salir."
                        read -p "Elija una opción: " OPCION_HTTP

                        case "$OPCION_HTTP" in
                            1)
                                downloadsApache="https://downloads.apache.org/httpd/"
                                page_apache=$(get_html "$downloadsApache")
                                mapfile -t versions < <(get_lts_version "$downloadsApache" 0)
                                last_lts_version=${versions[0]}

                                echo "¿Que versión de apache desea instalar"
                                echo "1. Última versión LTS $last_lts_version"
                                echo "2. Versión de desarrollo (No tiene)"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_APACHE

                                case "$OPCION_APACHE" in
                                    1)
                                        # Pedir el puerto al usuario
                                        read -p "Ingrese el puerto en el que se instalará Apache: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        # Verificar si el puerto esta disponible
                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            install_server_http_ssl "$downloadsApache" "httpd-$last_lts_version.tar.gz" "httpd-$last_lts_version" "apache2"
                                            # Verificar la instalacón
                                            /usr/local/apache2/bin/httpd -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/apache2"
                                            configure_ssl_apache "$routeFileConfiguration" "$PORT" "$HTTPS_PORT"
                                            sudo /usr/local/apache2/bin/apachectl restart
                                            echo "Configuracion lista"
                                        fi
                                    ;;
                                    2)
                                        echo "Apache no cuenta con versión de desarrollo."
                                        echo "Saliendo al menú principal..."
                                    ;;
                                    0)
                                        echo "Saliendo al menú principal..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            2)
                                echo "Instalar Tomcat..."
                                downloadsTomcat="https://tomcat.apache.org/index.html"
                                dev_version=$(get_lts_version "$downloadsTomcat" 0)
                                last_lts_version=$(get_lts_version "$downloadsTomcat" 1)

                                echo "¿Que versión de Tomcat desea instalar"
                                echo "1. Última versión LTS $last_lts_version"
                                echo "2. Versión de desarrollo $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_TOMCAT

                                case "$OPCION_TOMCAT" in
                                    1)
                                        fisrt_digit=$(get_first_digit 0 "$last_lts_version")
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 8443):" HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -s -O "https://dlcdn.apache.org/tomcat/tomcat-$fisrt_digit/v$last_lts_version/bin/apache-tomcat-$last_lts_version.tar.gz"
                                            tar -xzvf apache-tomcat-$last_lts_version.tar.gz
                                            sudo mv apache-tomcat-$last_lts_version /opt/tomcat

                                            # Generar el certificado SSL y keystore
                                            CERT_DIR="/opt/tomcat/conf"
                                            generate_ssl_cert_tomcat "$CERT_DIR"
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            KEYSTORE_PATH="conf/keystore.jks"
                                            KEYSTORE_PASS="changeit"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"

                                            # Agregar el conector HTTPS si no está presente
                                            if ! grep -q "Connector port=\"$HTTPS_PORT\"" "$server_xml"; then
                                                sudo sed -i "/<\/Service>/i \
                                                <Connector port=\"$HTTPS_PORT\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" \n\
                                                        maxThreads=\"200\" SSLEnabled=\"true\"> \n\
                                                    <SSLHostConfig> \n\
                                                        <Certificate certificateKeystoreFile=\"$KEYSTORE_PATH\" \n\
                                                                    type=\"RSA\" \n\
                                                                    certificateKeystorePassword=\"$KEYSTORE_PASS\"/> \n\
                                                    </SSLHostConfig> \n\
                                                </Connector>" "$server_xml"
                                            fi
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    2)
                                        fisrt_digit=$(get_first_digit 0 "$dev_version")
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 8443):" HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif ss -tuln | grep -q ":$HTTPS_PORT "; then
                                            echo "El puerto $HTTPS_PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -s -O "https://dlcdn.apache.org/tomcat/tomcat-$fisrt_digit/v$dev_version/bin/apache-tomcat-$dev_version.tar.gz"
                                            tar -xzvf apache-tomcat-$dev_version.tar.gz
                                            sudo mv apache-tomcat-$dev_version /opt/tomcat

                                            # Generar el certificado SSL y keystore
                                            CERT_DIR="/opt/tomcat/conf"
                                            generate_ssl_cert_tomcat "$CERT_DIR"
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            KEYSTORE_PATH="conf/keystore.jks"
                                            KEYSTORE_PASS="changeit"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"

                                            # Agregar el conector HTTPS si no está presente
                                            if ! grep -q "Connector port=\"$HTTPS_PORT\"" "$server_xml"; then
                                                sudo sed -i "/<\/Service>/i \
                                                <Connector port=\"$HTTPS_PORT\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" \n\
                                                        maxThreads=\"200\" SSLEnabled=\"true\"> \n\
                                                    <SSLHostConfig> \n\
                                                        <Certificate certificateKeystoreFile=\"$KEYSTORE_PATH\" \n\
                                                                    type=\"RSA\" \n\
                                                                    certificateKeystorePassword=\"$KEYSTORE_PASS\"/> \n\
                                                    </SSLHostConfig> \n\
                                                </Connector>" "$server_xml"
                                            fi
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            3)
                                echo "Instalar Nginx"
                                downloadsNginx="https://nginx.org/en/download.html"
                                dev_version=$(get_lts_version "$downloadsNginx" 0)
                                last_lts_version=$(get_lts_version "$downloadsNginx" 1)

                                echo "¿Que versión de Nginx desea instalar"
                                echo "1. Última versión LTS $last_lts_version"
                                echo "2. Versión de desarrollo $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_NGINX

                                case "$OPCION_NGINX" in
                                    1)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            install_server_http_ssl "https://nginx.org/download/" "nginx-$last_lts_version.tar.gz" "nginx-$last_lts_version" "nginx"
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx"
                                            configure_ssl_nginx "$routeFileConfiguration" "$PORT" "$HTTPS_PORT"
                                            ps aux | grep nginx
                                        fi
                                    ;;
                                    2)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        read -p "Ingrese el puerto HTTPS para SSL (recomendado 443): " HTTPS_PORT
                                        verificar_puerto_reservado -puerto $PORT
                                        verificar_puerto_reservado -puerto $HTTPS_PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            install_server_http_ssl "https://nginx.org/download/" "nginx-$dev_version.tar.gz" "nginx-$dev_version" "nginx"
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx"
                                            configure_ssl_nginx "$routeFileConfiguration" "$PORT" "$HTTPS_PORT"
                                            ps aux | grep nginx
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo al menú..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            0)
                                echo "Saliendo..."
                            ;;
                            *)
                                echo "Opción no válida."
                            ;;
                        esac
                    done
                ;;
                "no")
                    OPCION_HTTP=-1
                    while [ "$OPCION_HTTP" -ne 0 ]; do
                        echo "¿Qué servicio desea instalar?"
                        echo "1. Apache."
                        echo "2. Tomcat."
                        echo "3. Nginx."
                        echo "0. Salir."
                        read -p "Elija una opción: " OPCION_HTTP

                        case "$OPCION_HTTP" in
                            1)
                                downloadsApache="https://downloads.apache.org/httpd/"
                                page_apache=$(get_html "$downloadsApache")
                                mapfile -t versions < <(get_lts_version "$downloadsApache" 0)
                                last_lts_version=${versions[0]}

                                echo "¿Que versión de apache desea instalar"
                                echo "1. Última versión LTS $last_lts_version"
                                echo "2. Versión de desarrollo (No tiene)"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_APACHE

                                case "$OPCION_APACHE" in
                                    1)
                                        # Pedir el puerto al usuario
                                        read -p "Ingrese el puerto en el que se instalará Apache: " PORT
                                        verificar_puerto_reservado -puerto $PORT

                                        # Verificar si el puerto esta disponible
                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            install_server_http "$downloadsApache" "httpd-$last_lts_version.tar.gz" "httpd-$last_lts_version" "apache2"
                                            # Verificar la instalacón
                                            /usr/local/apache2/bin/httpd -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/apache2/conf/httpd.conf"
                                            # Remover el puerto en uso actual
                                            sudo sed -i '/^Listen/d' $routeFileConfiguration
                                            # Añadir puerto que eligio el usuario
                                            sudo printf "Listen $PORT" >> $routeFileConfiguration
                                            # Comprobar si el puerto esta escuchando
                                            sudo grep -i "Listen $PORT" $routeFileConfiguration
                                            sudo /usr/local/apache2/bin/apachectl restart
                                        fi
                                    ;;
                                    2)
                                        echo "Apache no cuenta con versión de desarrollo."
                                    ;;
                                    0)
                                        echo "Saliendo al menú principal..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            2)
                                echo "Instalar Tomcat..."
                                downloadsTomcat="https://tomcat.apache.org/index.html"
                                dev_version=$(get_lts_version "$downloadsTomcat" 0)
                                last_lts_version=$(get_lts_version "$downloadsTomcat" 1)

                                echo "¿Que versión de Tomcat desea instalar"
                                echo "1. Última versión LTS $last_lts_version"
                                echo "2. Versión de desarrollo $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_TOMCAT

                                case "$OPCION_TOMCAT" in
                                    1)
                                        fisrt_digit=$(get_first_digit 0 "$last_lts_version")
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        verificar_puerto_reservado -puerto $PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -s -O "https://dlcdn.apache.org/tomcat/tomcat-$fisrt_digit/v$last_lts_version/bin/apache-tomcat-$last_lts_version.tar.gz"
                                            tar -xzvf apache-tomcat-$last_lts_version.tar.gz
                                            sudo mv apache-tomcat-$last_lts_version /opt/tomcat
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    2)
                                        fisrt_digit=$(get_first_digit 0 "$dev_version")
                                        read -p "Ingrese el puerto en el que se instalará Tomcat: " PORT
                                        verificar_puerto_reservado -puerto $PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            # Instalar Java ya que Tomcat lo requiere
                                            sudo apt update
                                            sudo apt install default-jdk -y
                                            java -version
                                            curl -s -O "https://dlcdn.apache.org/tomcat/tomcat-$fisrt_digit/v$dev_version/bin/apache-tomcat-$dev_version.tar.gz"
                                            tar -xzvf apache-tomcat-$dev_version.tar.gz
                                            sudo mv apache-tomcat-$dev_version /opt/tomcat
                                            # Modificar el puerto en server.xml
                                            server_xml="/opt/tomcat/conf/server.xml"
                                            sudo sed -i "s/port=\"8080\"/port=\"$PORT\"/g" "$server_xml"
                                            # Otorgar permisos de ejecución
                                            sudo chmod +x /opt/tomcat/bin/*.sh
                                            # Iniciar Tomcat
                                            /opt/tomcat/bin/startup.sh
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            3)
                                echo "Instalar Nginx"
                                downloadsNginx="https://nginx.org/en/download.html"
                                dev_version=$(get_lts_version "$downloadsNginx" 0)
                                last_lts_version=$(get_lts_version "$downloadsNginx" 1)

                                echo "¿Que versión de Nginx desea instalar"
                                echo "1. Última versión LTS $last_lts_version"
                                echo "2. Versión de desarrollo $dev_version"
                                echo "0. Salir"
                                read -p "Eliga una opción: " OPCION_NGINX

                                case "$OPCION_NGINX" in
                                    1)
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        verificar_puerto_reservado -puerto $PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            install_server_http "https://nginx.org/download/" "nginx-$last_lts_version.tar.gz" "nginx-$last_lts_version" "nginx"
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx/conf/nginx.conf"
                                            # Modificar el puerto
                                            sed -i -E "s/listen[[:space:]]{7}[0-9]{1,5}/listen      $PORT/" "$routeFileConfiguration"
                                            # Verificar si esta escuchando en el puerto
                                            sudo grep -i "listen[[:space:]]{7}" "$routeFileConfiguration"
                                            sudo /usr/local/nginx/sbin/nginx
                                            sudo /usr/local/nginx/sbin/nginx -s reload
                                            ps aux | grep nginx
                                        fi
                                    ;;
                                    2)
                                        echo "Instalando al versión de desarrollo de Nginx..."
                                        read -p "Ingrese el puerto en el que se instalará Nginx: " PORT
                                        verificar_puerto_reservado -puerto $PORT

                                        if ss -tuln | grep -q ":$PORT "; then
                                            echo "El puerto $PORT esta en uso. Eliga otro."
                                        elif [[ $? -eq 0 ]]; then
                                            echo "El puerto $PORT esta ocupado en otro servicio."
                                        else
                                            install_server_http "https://nginx.org/download/" "nginx-$dev_version.tar.gz" "nginx-$dev_version" "nginx"
                                            # Verificar la instalación de Nginx
                                            /usr/local/nginx/sbin/nginx -v
                                            # Ruta de la configuración del archivo
                                            routeFileConfiguration="/usr/local/nginx/conf/nginx.conf"
                                            # Modificar el puerto
                                            sed -i -E "s/listen[[:space:]]{7}[0-9]{1,5}/listen      $PORT/" "$routeFileConfiguration"
                                            # Verificar si esta escuchando en el puerto
                                            sudo grep -i "listen[[:space:]]{7}" "$routeFileConfiguration"
                                            sudo /usr/local/nginx/sbin/nginx
                                            sudo /usr/local/nginx/sbin/nginx -s reload
                                            ps aux | grep nginx
                                        fi
                                    ;;
                                    0)
                                        echo "Saliendo..."
                                    ;;
                                    *)
                                        echo "Opción no válida."
                                    ;;
                                esac
                            ;;
                            0)
                                echo "Saliendo..."
                                exit 0
                            ;;
                            *)
                                echo "Opción no válida."
                            ;;
                        esac
                    done
                ;;
                *)
                    echo "Opción inválida (SI/NO)"
                ;;
            esac
        ;;
        0)
            echo "Saliendo..."
            exit 0
        ;;
        *)
            echo "Opción inválida."
        ;;
    esac
done