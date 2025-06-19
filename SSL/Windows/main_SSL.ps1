. C:\Users\Administrador\Documents\Funciones_SSL.ps1
. C:\Users\Administrador\Documents\Funciones_HTTP.ps1

# Generar certificado y habilitar SSL
$certificado = "C3B6B652E357C09F0895493D1601EFC3EAFCF251"
Habilitar-SSL -numeroCert $certificado
#Generate-SSLCertificate

Configure-FTPServer

$servidorFtp = "ftp://localhost"

while ($true) {
    Write-Host "¿Donde desea instalar el servicio?"
    Write-Host "1. FTP."
    Write-Host "2. Web."
    Write-Host "0. Salir."
    $OPCION = Read-Host "Eliga una opción"

    if($OPCION -eq "0"){
        Write-Output "Saliendo..."
        break
    } elseif ($OPCION -notmatch "^\d+$"){
        Write-Output "Debes ingresar un número."
    } else {
        switch ($OPCION) {
            "1"{
                Write-Host "Instalar por FTP..."
                while ($true) {
                    Write-Host "¿Que servicio desea instalar?"
                    Write-Host "1. Caddy."
                    Write-Host "2. Nginx."
                    Write-Host "0. Salir"
                    $opc = Read-Host "Eliga una opción"

                    if($opc -eq "0"){
                        Write-Output "Saliendo..."
                        break
                    } elseif ($opc -notmatch "^\d+$"){
                        Write-Output "Debes ingresar un número."
                    } else {
                        switch ($opc) {
                            1{
                                Write-Host "Instalar Caddy..."
                                Write-Host "Intentando conectar a: $servidorFtp"
                                listar-Carpetas-FTP -servidorFtp "$servidorFtp/windows/Caddy"
                                $page_Caddy = Invoke-RestMethod "https://api.github.com/repos/caddyserver/caddy/releases"
                                $versionsCaddy = $page_Caddy
                                $ltsVersion = $versionsCaddy[6].tag_name
                                $devVersion = $versionsCaddy[0].tag_name
                                Write-Output "¿Que versión de Caddy desea instalar?"
                                Write-Output "1. Última versión LTS $ltsVersion"
                                Write-Output "2. Versión de desarrollo $devVersion"
                                Write-Output "0. Salir"
                                $OPCION_CADDY = Read-Host -p "Eliga una opción"

                                switch ($OPCION_CADDY) {
                                     "1"{ 
                                        $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                
                                        if ($PORT -notmatch "^\d+$") {
                                            Write-Output "Debes ingresar un número."
                                        } elseif (VerifyPortsReserved -port $PORT) {
                                            Write-Host "El puerto $PORT está reservado para un servicio ."
                                        } else {
                                            $opc_ssl = Read-Host "¿Desea activar SSL en Caddy?"
                                            Stop-Process -Name caddy -ErrorAction SilentlyContinue
                                            curl.exe "$servidorFtp/windows/Caddy/caddy-$ltsVersion.zip" --ftp-ssl -k -o "C:\descargas\caddy-$ltsVersion.zip"
                                            Expand-Archive C:\descargas\caddy-$ltsVersion.zip C:\descargas -Force
                                            cd C:\descargas
                                            New-Item c:\descargas\Caddyfile -type file -Force
                                            
                                            if ($opc_ssl.ToLower() -eq "si"){
                                                Write-Host "Activando SSL en Caddy..."
                                                Clear-Content -Path "C:\descargas\Caddyfile"
                                                Set-Content -Path "C:\descargas\Caddyfile" -Value @"
                                                {
                                                    https_port $PORT
                                                    auto_https disable_redirects
                                                }

                                                https://localhost:$PORT {
                                                    root * "C:/MySite"
                                                    file_server browse
                                                    tls internal
                                                }
                                                "@

                                                Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                Select-String -Path "C:\descargas\Caddyfile" -Pattern ":$PORT"
                                            } elseif ($opc_ssl.ToLower() -eq "no") {
                                                Clear-Content -Path "C:\descargas\Caddyfile"
                                                Set-Content -Path "C:\descargas\Caddyfile" -Value "@
                                                :$PORT {
                                                    root * "C:/MySite"
                                                    file_server
                                                }
                                                "@

                                                Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                Select-String -Path "C:\descargas\Caddyfile" -Pattern ":$PORT"
                                            }else {
                                                Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                            }
                                        }
                                    }
                                    "2"{
                                        $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                
                                        if ($PORT -notmatch "^\d+$") {
                                            Write-Output "Debes ingresar un número."
                                        } elseif (VerifyPortsReserved -port $PORT) {
                                            Write-Host "El puerto $PORT está reservado para un servicio ."
                                        } else {
                                            $opc_ssl = Read-Host "¿Desea activar SSL en Caddy?"
                                            Stop-Process -Name caddy -ErrorAction SilentlyContinue
                                            curl.exe "$servidorFtp/windows/Caddy/caddy-$devVersion.zip" --ftp-ssl -k -o "C:\descargas\caddy-$devVersion.zip"
                                            Expand-Archive C:\descargas\caddy-$devVersion.zip C:\descargas -Force
                                            cd C:\descargas
                                            New-Item c:\descargas\Caddyfile -type file -Force
                                            
                                            if ($opc_ssl.ToLower() -eq "si"){
                                                Write-Host "Activando SSL en Caddy..."
                                                Clear-Content -Path "C:\descargas\Caddyfile"
                                                Set-Content -Path "C:\descargas\Caddyfile" -Value @"
                                                {
                                                    https_port $PORT
                                                    auto_https disable_redirects
                                                }

                                                https://localhost:$PORT {
                                                    root * "C:/MySite"
                                                    file_server browse
                                                    tls internal
                                                }
                                                "@

                                                Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                Select-String -Path "C:\descargas\Caddyfile" -Pattern ":$PORT"
                                            } elseif ($opc_ssl.ToLower() -eq "no") {
                                                Clear-Content -Path "C:\descargas\Caddyfile"
                                                Set-Content -Path "C:\descargas\Caddyfile" -Value "@
                                                :$PORT {
                                                    root * "C:/MySite"
                                                    file_server
                                                }
                                                "@

                                                Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                Select-String -Path "C:\descargas\Caddyfile" -Pattern ":$PORT"
                                            }else {
                                                Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                            }
                                        }
                                    }
                                    Default {

                                    }
                                }
                            }
                            2{
                                Write-Host "Instalar Nginx..."
                                Write-Output "Instalar Nginx..."
                                listar-Carpetas-FTP -servidorFtp "$servidorFtp/windows/Nginx"
                                $downloadsNginx = "https://nginx.org/en/download.html"
                                $page_Nginx = (Get-HTML -url $downloadsNginx)
                                $versionsNginx = (get-version-format -page $page_Nginx)
                                $ltsVersion = $versionsNginx[1]
                                $devVersion = $versionsNginx[0]

                                Write-Output "¿Que versión de Nginx desea instalar?"
                                Write-Output "1. Última versión LTS $ltsVersion"
                                Write-Output "2. Versión de desarrollo $devVersion"
                                Write-Output "0. Salir"
                                $OPCION_NGINX = Read-Host -p "Eliga una opción"

                                if ($OPCION_NGINX -notmatch "^\d+$") {
                                    Write-Output "Debes ingresar un número."
                                } else {
                                    switch ($OPCION_NGINX) {
                                        "1"{
                                            $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                                            if ($PORT -notmatch "^\d+$") {
                                                Write-Output "Debes ingresar un número."
                                            } elseif (VerifyPortsReserved -port $PORT) {
                                                Write-Host "El puerto $PORT está reservado para un servicio ."
                                            } else {
                                                $opc_ssl = Read-Host "¿Desea habilitar SSL?"
                                                if ($opc_ssl.ToLower() -eq "si") {
                                                    Write-Host "Se habilitará el SSL en Nginx..."
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    curl.exe "$servidorFtp/windows/Nginx/nginx-$ltsVersion.zip" --ftp-ssl -k -o "C:\descargas\nginx-$ltsVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$ltsVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$ltsVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen 81;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }

                                                        # Configuración del servidor HTTPS
                                                        server {
                                                            listen $PORT ssl;
                                                            server_name localhost;

                                                            ssl_certificate c:\descargas\certificate.crt;
                                                            ssl_certificate_key c:\descargas\private.key;

                                                            ssl_protocols TLSv1.2 TLSv1.3;
                                                            ssl_ciphers HIGH:!aNULL:!MD5;

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
                                                    "@
                                        
                                                    Set-Content -Path "C:\descargas\nginx-$ltsVersion\conf\nginx.conf" -Value $contenido
                                                } elseif ($opc_ssl.ToLower() -eq "no") {
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    curl.exe "$servidorFtp/windows/Nginx/nginx-$ltsVersion.zip" --ftp-ssl -k -o "C:\descargas\nginx-$ltsVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$ltsVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$ltsVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen $PORT;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }
                                                    }
                                                    "@
                                                    Set-Content -Path "C:\descargas\nginx-$ltsVersion\conf\nginx.conf" -Value $contenido
                                                } else {
                                                    Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                                }
                                            }
                                        }
                                        "2"{
                                            $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                                            if ($PORT -notmatch "^\d+$") {
                                                Write-Output "Debes ingresar un número."
                                            } elseif (VerifyPortsReserved -port $PORT) {
                                                Write-Host "El puerto $PORT está reservado para un servicio ."
                                            } else {
                                                $opc_ssl = Read-Host "¿Desea habilitar SSL?"
                                                if ($opc_ssl.ToLower() -eq "si") {
                                                    Write-Host "Se habilitará el SSL en Nginx..."
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    curl.exe "$servidorFtp/windows/Nginx/nginx-$devVersion.zip" --ftp-ssl -k -o "C:\descargas\nginx-$devVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$devVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$devVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen 81;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }

                                                        # Configuración del servidor HTTPS
                                                        server {
                                                            listen $PORT ssl;
                                                            server_name localhost;

                                                            ssl_certificate c:\descargas\certificate.crt;
                                                            ssl_certificate_key c:\descargas\private.key;

                                                            ssl_protocols TLSv1.2 TLSv1.3;
                                                            ssl_ciphers HIGH:!aNULL:!MD5;

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
                                                    "@
                                        
                                                    Set-Content -Path "C:\descargas\nginx-$devVersion\conf\nginx.conf" -Value $contenido
                                                } elseif ($opc_ssl.ToLower() -eq "no") {
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    curl.exe "$servidorFtp/windows/Nginx/nginx-$devVersion.zip" --ftp-ssl -k -o "C:\descargas\nginx-$devVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$devVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$devVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen $PORT;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }
                                                    }
                                                    "@
                                                    Set-Content -Path "C:\descargas\nginx-$devVersion\conf\nginx.conf" -Value $contenido
                                                } else {
                                                    Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                                }
                                            }
                                        }
                                        "0"{
                                            Write-Host "Saliendo..."
                                        }
                                    }
                                }
                            }
                            Default{
                                Write-Host "Ingrese una opción válida."
                            }
                        }
                    }
                }
             }
             "2"{
                Write-Host "Instalar por la Web..."
                while ($true) {
                    Write-Host "¿Que servicio desea instalar?"
                    Write-Host "1. IIS."
                    Write-Host "2. Caddy."
                    Write-Host "3. Nginx."
                    Write-Host "0. Salir."
                    $opc = Read-Host "Eliga una opción"
                    
                    if($opc -eq "0"){
                        Write-Output "Saliendo..."
                        break
                    } elseif ($opc -notmatch "^\d+$"){
                        Write-Output "Debes ingresar un número."
                    } else {
                        switch ($opc) {
                            "1"{ 
                                $PORT = Read-Host "Ingrese un puerto para instalar el servicio"
                                
                                if ($PORT -notmatch "^\d+$") {
                                    Write-Output "Debes ingresar un número."
                                } elseif (VerifyPortsReserved -port $PORT) {
                                    Write-Host "El puerto $PORT está reservado para un servicio ."
                                } else {
                                    Write-Output "Instalando el servicio IIS..."
                                    Install-WindowsFeature -Name Web-Server
                                    $opc_ssl = Read-Host "¿Desea habilitar SSL?"
                                    if ($opc_ssl.ToLower() -eq "si") {
                                        # Crear un certificado autofirmado
                                        $nombreDominio = $env:COMPUTERNAME
                                        $cert = New-SelfSignedCertificate -DnsName $nombreDominio -CertStoreLocation "cert:\LocalMachine\My" -FriendlyName "Certificado Autofirmado IIS" -NotAfter (Get-Date).AddYears(5)

                                        # Obtener el thumbprint del certificado
                                        $thumbprint = $cert.Thumbprint
                                        Write-Host "Thumbprint del certificado: $thumbprint"

                                        # Crear una vinculación HTTPS en el sitio web predeterminado (o cambia "Default Web Site" por el nombre de tu sitio)
                                        New-WebBinding -Name "IIS" -IP "*" -Port $PORT -Protocol https

                                        # Asignar el certificado a la vinculación HTTPS
                                        $binding = Get-WebBinding -Name "IIS" -Protocol "https"
                                        $binding.AddSslCertificate($thumbprint, "my")

                                        # Verificar que la vinculación se ha creado correctamente
                                        Get-WebBinding -Name "IIS"
                                        Write-Host "IIS Se ha instalado correctamente"
                                    } elseif ($opc_ssl.ToLower() -eq "no") {
                                        Set-WebBinding -Name "IIS" -BindingInformation "*:80:" -PropertyName "bindingInformation" -Value ("*:" + $PORT + ":")
                                        iisreset
                                        Write-Host "IIS Se ha instalado correctamente"
                                    } else{
                                        Write-Host "Opción no válida, solo se acepta 'si' o 'no'."
                                    }
                                }
                            }
                            "2"{
                                Write-Host "Instalar Caddy..."
                                $page_Caddy = Invoke-RestMethod "https://api.github.com/repos/caddyserver/caddy/releases"
                                $versionsCaddy = $page_Caddy
                                $ltsVersion = $versionsCaddy[6].tag_name
                                $devVersion = $versionsCaddy[0].tag_name
                                Write-Output "¿Que versión de Caddy desea instalar?"
                                Write-Output "1. Última versión LTS $ltsVersion"
                                Write-Output "2. Versión de desarrollo $devVersion"
                                Write-Output "0. Salir"
                                $OPCION_CADDY = Read-Host -p "Eliga una opción"

                                if ($OPCION_CADDY -notmatch "^\d+$") {
                                    Write-Output "Debes ingresar un número."
                                } else {
                                    switch($OPCION_CADDY){
                                        "1"{
                                            $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                
                                            if ($PORT -notmatch "^\d+$") {
                                                Write-Output "Debes ingresar un número."
                                            } elseif (VerifyPortsReserved -port $PORT) {
                                                Write-Host "El puerto $PORT está reservado para un servicio ."
                                            } else {
                                                $opc_ssl = Read-Host "¿Desea activar SSL en Caddy?"
                                                Stop-Process -Name caddy -ErrorAction SilentlyContinue
                                                # Obtiene la versión limpia de Caddy (parece que "quit-V" es una función personalizada, debería verificarse).
                                                $ltsVersionClean = (quit-V -version "$ltsVersion")
                                                Invoke-WebRequest -UseBasicParsing "https://github.com/caddyserver/caddy/releases/download/$ltsVersion/caddy_${ltsVersionClean}_windows_amd64.zip" -Outfile "C:\Descargas\caddy-$ltsVersion.zip"
                                                Expand-Archive C:\descargas\caddy-$ltsVersion.zip C:\descargas -Force
                                                cd C:\descargas
                                                New-Item c:\descargas\Caddyfile -type file -Force
                                                
                                                if ($opc_ssl.ToLower() -eq "si"){
                                                    Write-Host "Activando SSL en Caddy..."
                                                    Clear-Content -Path "C:\descargas\Caddyfile"
                                                    Set-Content -Path "C:\descargas\Caddyfile" -Value @"
                                                    {
                                                        https_port $PORT
                                                        auto_https disable_redirects
                                                    }

                                                    localhost:$PORT {
                                                        root * "C:/MySite"
                                                        file_server browse
                                                        tls internal
                                                    }
                                                    "@

                                                    Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                    Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                    Select-String -Path "C:\descargas\Caddyfile" -Pattern ":$PORT"
                                                } elseif ($opc_ssl.ToLower() -eq "no") {
                                                    Clear-Content -Path "C:\descargas\Caddyfile"
                                                    Set-Content -Path "C:\descargas\Caddyfile" -Value "@
                                                    :$PORT {
                                                        root * "C:/MySite"
                                                        file_server
                                                    }
                                                    "@

                                                    Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                    Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                    Select-String -Path "C:\descargas\Caddyfile" -Pattern ":$PORT"
                                                }else {
                                                    Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                                }
                                            }
                                        }
                                        "2"{
                                            $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                
                                            if ($PORT -notmatch "^\d+$") {
                                                Write-Output "Debes ingresar un número."
                                            } elseif ($PORT -lt 1023 -or $PORT -gt 65536) {
                                                Write-Output "Puerto no válido, debe estar entre 1024 y 65535."
                                            } elseif (VerifyPortsReserved -port $PORT) {
                                                Write-Host "El puerto $PORT está reservado para un servicio ."
                                            } else {
                                                $opc_ssl = Read-Host "¿Desea activar SSL en Caddy?"
                                                Stop-Process -Name caddy -ErrorAction SilentlyContinue
                                                # Obtiene la versión limpia de Caddy (parece que "quit-V" es una función personalizada, debería verificarse).
                                                $devVersionClean = (quit-V -version "$devVersion")
                                                Invoke-WebRequest -UseBasicParsing "https://github.com/caddyserver/caddy/releases/download/$devVersion/caddy_${devVersionClean}_windows_amd64.zip" -Outfile "C:\Descargas\caddy-$devVersion.zip"
                                                Expand-Archive C:\Descargas\caddy-$devVersion.zip C:\Descargas -Force
                                                cd C:\Descargas
                                                New-Item c:\Descargas\Caddyfile -type file -Force
                                                
                                                if ($opc_ssl.ToLower() -eq "si"){
                                                    Write-Host "Activando SSL en Caddy..."
                                                    Clear-Content -Path "C:\descargas\Caddyfile"
                                                    Set-Content -Path "C:\descargas\Caddyfile" -Value @"
                                                    {
                                                        https_port $PORT
                                                        auto_https disable_redirects
                                                    }

                                                    localhost:$PORT {
                                                        root * "C:/MySite"
                                                        file_server browse
                                                        tls internal
                                                    }
                                                    "@

                                                    Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                    Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                    Select-String -Path "C:\Descargas\Caddyfile" -Pattern ":$PORT"
                                                } elseif ($opc_ssl.ToLower() -eq "no") {
                                                    Clear-Content -Path "C:\descargas\Caddyfile"
                                                    Set-Content -Path "C:\descargas\Caddyfile" -Value "
                                                    :$PORT {
                                                        root * "C:/MySite"
                                                        file_server
                                                    }
                                                    "@

                                                    Start-Process -NoNewWindow -FilePath "C:\descargas\caddy.exe" -ArgumentList "run --config C:\descargas\Caddyfile"
                                                    Get-Process | Where-Object { $_.ProcessName -like "*caddy*" }
                                                    Select-String -Path "C:\Descargas\Caddyfile" -Pattern ":$PORT"
                                                }else {
                                                    Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                                }
                                            }
                                        }                               
                                    }
                                }
                            }
                            "3"{
                                Write-Host "Instalar Nginx..."
                                Write-Output "Instalar Nginx..."
                                $downloadsNginx = "https://nginx.org/en/download.html"
                                $page_Nginx = (Get-HTML -url $downloadsNginx)
                                $versionsNginx = (get-version-format -page $page_Nginx)
                                $ltsVersion = $versionsNginx[1]
                                $devVersion = $versionsNginx[0]

                                Write-Output "¿Que versión de Nginx desea instalar?"
                                Write-Output "1. Última versión LTS $ltsVersion"
                                Write-Output "2. Versión de desarrollo $devVersion"
                                Write-Output "0. Salir"
                                $OPCION_NGINX = Read-Host -p "Eliga una opción"

                                if ($OPCION_NGINX -notmatch "^\d+$") {
                                    Write-Output "Debes ingresar un número."
                                } else {
                                    switch ($OPCION_NGINX) {
                                        "1" { 
                                            $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                                            if ($PORT -notmatch "^\d+$") {
                                                Write-Output "Debes ingresar un número."
                                            } elseif (VerifyPortsReserved -port $PORT) {
                                                Write-Host "El puerto $PORT está reservado para un servicio ."
                                            } else {
                                                $opc_ssl = Read-Host "¿Desea habilitar SSL?"
                                                if ($opc_ssl.ToLower() -eq "si") {
                                                    Write-Host "Se habilitará el SSL en Nginx..."
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    Invoke-WebRequest -UseBasicParsing "https://nginx.org/download/nginx-$ltsVersion.zip" -Outfile "C:\Descargas\nginx-$ltsVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$ltsVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$ltsVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen 81;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }

                                                        # Configuración del servidor HTTPS
                                                        server {
                                                            listen $PORT ssl;
                                                            server_name localhost;

                                                            ssl_certificate c:\descargas\certificate.crt;
                                                            ssl_certificate_key c:\descargas\private.key;

                                                            ssl_protocols TLSv1.2 TLSv1.3;
                                                            ssl_ciphers HIGH:!aNULL:!MD5;

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
                                                    "@
                                        
                                                    Set-Content -Path "C:\descargas\nginx-$ltsVersion\conf\nginx.conf" -Value $contenido
                                                } elseif ($opc_ssl.ToLower() -eq "no") {
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    Invoke-WebRequest -UseBasicParsing "https://nginx.org/download/nginx-$ltsVersion.zip" -Outfile "C:\Descargas\nginx-$ltsVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$ltsVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$ltsVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen $PORT;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }
                                                    }
                                                    "@
                                                    Set-Content -Path "C:\descargas\nginx-$ltsVersion\conf\nginx.conf" -Value $contenido
                                                } else {
                                                    Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                                }
                                            }
                                        }
                                        "2"{
                                            $PORT = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                                            if ($PORT -notmatch "^\d+$") {
                                                Write-Output "Debes ingresar un número."
                                            } elseif (VerifyPortsReserved -port $PORT) {
                                                Write-Host "El puerto $PORT está reservado para un servicio ."
                                            } else {
                                                $opc_ssl = Read-Host "¿Desea habilitar SSL?"
                                                if ($opc_ssl.ToLower() -eq "si") {
                                                    Write-Host "Se habilitará el SSL en Nginx..."
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    Invoke-WebRequest -UseBasicParsing "https://nginx.org/download/nginx-$devVersion.zip" -Outfile "C:\Descargas\nginx-$devVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$devVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$devVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen 81;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }

                                                        # Configuración del servidor HTTPS
                                                        server {
                                                            listen $PORT ssl;
                                                            server_name localhost;

                                                            ssl_certificate c:\descargas\certificate.crt;
                                                            ssl_certificate_key c:\descargas\private.key;

                                                            ssl_protocols TLSv1.2 TLSv1.3;
                                                            ssl_ciphers HIGH:!aNULL:!MD5;

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
                                                    "@
                                        
                                                    Set-Content -Path "C:\descargas\nginx-$devVersion\conf\nginx.conf" -Value $contenido
                                                } elseif ($opc_ssl.ToLower() -eq "no") {
                                                    Stop-Process -Name nginx -ErrorAction SilentlyContinue
                                                    Invoke-WebRequest -UseBasicParsing "https://nginx.org/download/nginx-$devVersion.zip" -Outfile "C:\Descargas\nginx-$devVersion.zip"
                                                    Expand-Archive C:\Descargas\nginx-$devVersion.zip C:\Descargas -Force
                                                    cd C:\Descargas\nginx-$devVersion
                                                    Start-Process nginx.exe
                                                    Get-Process | Where-Object { $_.ProcessName -like "*nginx*" }
                                                    cd ..
                                                    $contenido = @"
                                                    worker_processes  1;

                                                    events {
                                                        worker_connections  1024;
                                                    }

                                                    http {
                                                        include       mime.types;
                                                        default_type  application/octet-stream;

                                                        sendfile        on;
                                                        keepalive_timeout  65;

                                                        # Configuración del servidor HTTP (redirige a HTTPS)
                                                        server {
                                                            listen $PORT;
                                                            server_name localhost;

                                                            location / {
                                                                root   html;
                                                                index  index.html index.htm;
                                                            }
                                                        }
                                                    }
                                                    "@
                                                    Set-Content -Path "C:\descargas\nginx-$ltsVersion\conf\nginx.conf" -Value $contenido
                                                } else {
                                                    Write-Host "Opción no válida, debe ser 'si' o 'no'."
                                                }
                                            }
                                        }
                                        Default {
                                            Write-Host "Opción no válida."
                                        }
                                    }
                                }
                            }
                            Default {
                                Write-Host "Ingrese una opción válida."
                            }
                        }
                    }
                }
            }
            Default {
                Write-Host "Ingrese una opción válida."
            }
        }
    }
}