$ProgressPreference = 'SilentlyContinue'

# Verificar si Chocolatey está instalado
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey no está instalado. Instalando..."
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
    Write-Host "Chocolatey ya está instalado."
}
netsh advfirewall set allprofiles state off
Disable-NetFirewallRule

# Verificar si OpenSSL está instalado (revisa el paquete de Chocolatey)
$opensslInstalado = choco list openssl | Select-String '^openssl'

if (-not $opensslInstalado) {
    Write-Host "OpenSSL no está instalado. Instalando..."
    choco install openssl -y
} else {
    Write-Host "OpenSSL ya está instalado."
}

new-item -Path "C:\descargas" -ItemType Directory -Force | Out-Null
$opcDescarga = Read-Host "Desde donde quieres realizar la instalacion de los servicios? (web/ftp)"

$servidorFtp = "ftp://127.0.0.1"

function Es-PuertoValido([int]$puerto) {
    $puertosReservados = @{
        20 = "FTP"
        21 = "FTP"
        22 = "SSH"
        23 = "Telnet"
        25 = "SMTP"
        53 = "DNS"
        67 = "DHCP"
        68 = "DHCP"
        80 = "HTTP"
        110 = "POP3"
        119 = "NNTP"
        123 = "NTP"
        143 = "IMAP"
        161 = "SNMP"
        162 = "SNMP"
        389 = "LDAP"
        443 = "HTTPS"
    }

    if ($puertosReservados.ContainsKey($puerto)) {
        echo "No se puede utilizar ese puerto porque está reservado para el servicio $($puertosReservados[$puerto])"
        return $false
    }
    
    return $true
}

function Es-RangoValido([int]$puerto){
    if($puerto -lt 0 -or $puerto -gt 65535){
        return $false
    }
    else{
        return $true
    }
}

function Es-PuertoEnUso([int]$puerto){
    $enUso = Get-NetTCPConnection -LocalPort $puerto -ErrorAction SilentlyContinue
    if($enUso){return $true}
    return $false
}


function Es-Numerico([string]$string){
    return $string -match "^[0-9]+$"
}

function hacerPeticion([string]$url){
    return Invoke-WebRequest -UseBasicParsing -URI $url
}

function encontrarValor([string]$regex, [string]$pagina){
    $coincidencias = [regex]::Matches($pagina, $regex) | ForEach-Object { $_.Value }
    return $coincidencias
}

function quitarPrimerCaracter([string]$string){
    $stringSinPrimerCaracter = ""
    for($i = 1; $i -lt $string.length; $i++){
        $stringSinPrimerCaracter += $string[$i]
    }
    return $stringSinPrimerCaracter
}

function listarDirectoriosFtp {
    param (
        [string]$servidorFtp
    )

    
    try {
        Write-Host "Inicializando conexión a: $servidorFtp"

        # Aceptar cualquier certificado SSL (no usar en producción)
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
            param ($sender, $certificate, $chain, $sslPolicyErrors)
            return $true
        }

        $request = [System.Net.FtpWebRequest]::Create($servidorFtp)
        $request.Method = [System.Net.WebRequestMethods+FTP]::ListDirectory
        $request.Credentials = New-Object System.Net.NetworkCredential("anonymous", "anonymous@example.com")
        $request.EnableSsl = $true
        $request.UsePassive = $true
        $request.UseBinary = $true
        $request.KeepAlive = $false

        $response = $request.GetResponse()

        $reader = New-Object IO.StreamReader $response.GetResponseStream()
        $contenido = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()

        $contenido -split "`n" | ForEach-Object { $_.Trim() }
    }
    catch {
        Write-Error "Error detectado: $_"
        if ($_.Exception.Response -ne $null) {
            $resp = $_.Exception.Response
            Write-Host "Código de estado FTP: $($resp.StatusCode)"
            Write-Host "Descripción del estado: $($resp.StatusDescription)"
        }
    }
    finally {
        # Restaurar el validador de certificados al original
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }
}

function Es-ArchivoExistente($rutaDirectorio, $archivoABuscar){
    forEach($file in Get-ChildItem -Path $rutaDirectorio){
        if($file.Name -eq $archivoABuscar){
            return $true
        }
    }
    return $false
}

$versionRegex = "[0-9]+.[0-9]+.[0-9]"

if($opcDescarga.ToLower() -eq "ftp"){
    while($true){
        listarDirectoriosFtp -servidorFtp $servidorFtp
        echo "Menu de instalacion FTP"
        echo "Elige el servicio a instalar"
        $opc = Read-Host "Selecciona una opcion (escribe salir para salir)"
        $opc = $opc.ToLower()

        if($opc -eq "salir"){
            echo "Saliendo..."
            break
        }

        switch($opc){
            "caddy"{
                listarDirectoriosFtp -servidorFtp "$servidorFtp/Caddy"
                $objetosCaddy = Invoke-RestMethod "https://api.github.com/repos/caddyserver/caddy/releases"
                $versionesCaddy = $objetosCaddy
                $versionDesarrolloCaddy = $versionesCaddy[0].tag_name
                $versionLTSCaddy = $versionesCaddy[6].tag_name

                echo "Instalador de Caddy"
                echo "1. Version LTS $versionLTSCaddy"
                echo "2. Version de desarrollo $versionDesarrolloCaddy"
                echo "3. Salir"
                $opcCaddy = Read-Host "Selecciona una version"
                
                switch($opcCaddy){
                    "1"{
                        try {
                            $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                            if(-not(Es-Numerico -string $puerto)){
                                echo "Ingresa un valor numerico entero"
                            }
                            elseif(-not(Es-RangoValido $puerto)){
                                echo "Ingresa un puerto dentro del rango (0-65535)"
                            }
                            elseif(Es-PuertoEnUso $puerto){
                                echo "El puerto se encuentra en uso"
                            }
                            elseif(-not(Es-PuertoValido $puerto)){
                                echo "Error"
                            }
                            else {
                                $versionSinV = quitarPrimerCaracter -string $versionLTSCaddy
                                echo "Instalando version LTS $versionLTSCaddy"
                                curl.exe "$servidorFtp/Caddy/caddy-$versionLTSCaddy.zip" --ftp-ssl -k -o "C:\descargas\caddy-$versionLTSCaddy.zip"

                                Expand-Archive -Path "C:\descargas\caddy-$versionLTSCaddy.zip" -DestinationPath C:\caddy
                                cd C:\caddy
                                New-Item -Path "C:\caddy\www\" -ItemType "Directory"

                                #creo un archivo html que mostrara el servicio al conectarnos
                                New-Item -Path "C:\caddy\www\" -Name "index.html" -ItemType "File"
                                $HTMLcontent = @"
<html>
    <h1>Caddy LTS desde FTP</h1>
</html>
"@

                                #Creo el caddyfile y añado la configuracion inicial
                                $HTMLcontent | Out-File -Encoding utf8 -FilePath "C:\caddy\www\index.html"
                                $CaddyfileContent = @"
{
    auto_https off
}

:$puerto {
    root * C:/caddy/www/
    file_server
}

"@
                                $CaddyfileContent | Out-File -Encoding utf8 -FilePath "C:\caddy\Caddyfile"
                                C:\caddy\caddy.exe fmt --overwrite

                                $running = $true

                                #Pregunta para activar el ssl 
                                while($running){
                                    Write-Host "Quieres configurar SSL para Caddy [S-N]"
                                    $opc = Read-Host "Opcion"
                                    if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                        
                                        $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                        Export-PfxCertificate -Cert $cert -FilePath C:\caddy\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                        Export-Certificate -Cert $cert -FilePath "C:\caddy\certificado.crt"
                                        openssl pkcs12 -in C:\caddy\certificado.pfx -nocerts -nodes -out C:\caddy\clave.key -passin pass:Hola9080
                                        openssl pkcs12 -in C:\caddy\certificado.pfx -clcerts -nodes -out C:\caddy\certificado.crt -passin pass:Hola9080

                                        $running = $true
                                        while ($running){
                                            $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                            if(Es-PuertoValido $newPort){
                                            $puertovalido = $true
                                            Write-Host "Puerto Valido, se procederá a la configuracion"
                                            
                                            $running = $false       
                                            }else{
                                                $puertovalido = $false
                                                Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                            
                                            }
                                        }

                                        $httpsConfig = @"
:$newPort {
    tls C:/caddy/certificado.crt C:/caddy/clave.key
    root * C:/caddy/www/
    file_server
}

"@
                                    #Añade añ final del caddyfile la seccion para https
                                    Add-Content -Path "C:\caddy\Caddyfile" -Value $httpsConfig
                                    C:\caddy\caddy.exe fmt --overwrite C:\caddy\Caddyfile
                                        
                                        $running = $false
                                    }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                        $running = $false
                                    }else{
                                        Write-Host "Opcion Invalida"
                                    }   
                                }

                                Write-Host "Iniciando Servicio..."
                                try{
                                    #Start-Process -FilePath "C:\caddy\caddy.exe" -ArgumentList "caddy run" -PassThru -WindowStyle Hidden
                                    & "C:\caddy\caddy.exe" run --config C:\caddy\Caddyfile
                                    Write-Host "Servicio Iniciado con Status: "
                                    Start-Sleep -Seconds 2
                                
                                if (Get-Process caddy -ErrorAction SilentlyContinue) {
                                    Write-Host "Caddy se está ejecutando correctamente."
                                } else {
                                    Write-Host "Error al iniciar Caddy."
                                }
                                }catch {
                                    Write-Host "Error al iniciar el servicio Caddy: $($_.Exception.Message)"
                                }
                            }
                        }
                        catch {
                            echo $Error[0].ToString()
                        }
                        cd C:\Users\Administrador
                    }
                    "2"{
                        try{
                            $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                            if(-not(Es-Numerico -string $puerto)){
                                echo "Ingresa un valor numerico entero"
                            }
                            elseif(-not(Es-RangoValido $puerto)){
                                echo "Ingresa un puerto dentro del rango (0-65535)"
                            }
                            elseif(Es-PuertoEnUso $puerto){
                                echo "El puerto se encuentra en uso"
                            }
                            elseif(-not(Es-PuertoValido $puerto)){
                                echo "Error"
                            }
                            else{
                                Stop-Process -Name caddy -ErrorAction SilentlyContinue
                                $versionSinV = quitarPrimerCaracter -string $versionDesarrolloCaddy
                                echo $versionSinV
                                echo "Instalando version LTS $versionDesarrolloCaddy"
                                curl.exe "$servidorFtp/Caddy/caddy-$versionDesarrolloCaddy.zip" --ftp-ssl -k -o "C:\descargas\caddy-$versionDesarrolloCaddy.zip"
                                
                                Expand-Archive -Path "C:\descargas\caddy-$versionDesarrolloCaddy.zip" -DestinationPath C:\caddy
                                cd C:\caddy
                                New-Item -Path "C:\caddy\www\" -ItemType "Directory"

                                #creo un archivo html que mostrara el servicio al conectarnos
                                New-Item -Path "C:\caddy\www\" -Name "index.html" -ItemType "File"
                                $HTMLcontent = @"
<html>
    <h1>Caddy de Desarrollo desde FTP</h1>
</html>
"@

                                #Creo el caddyfile y añado la configuracion inicial
                                $HTMLcontent | Out-File -Encoding utf8 -FilePath "C:\caddy\www\index.html"
                                $CaddyfileContent = @"
{
    auto_https off
}

:$puerto {
    root * C:/caddy/www/
    file_server
}

"@
                                $CaddyfileContent | Out-File -Encoding utf8 -FilePath "C:\caddy\Caddyfile"
                                C:\caddy\caddy.exe fmt --overwrite

                                $running = $true

                                #Pregunta para activar el ssl 
                                while($running){
                                    Write-Host "Quieres configurar SSL para Caddy [S-N]"
                                    $opc = Read-Host "Opcion"
                                    if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                        
                                        $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                        Export-PfxCertificate -Cert $cert -FilePath C:\caddy\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                        Export-Certificate -Cert $cert -FilePath "C:\caddy\certificado.crt"
                                        openssl pkcs12 -in C:\caddy\certificado.pfx -nocerts -nodes -out C:\caddy\clave.key -passin pass:Hola9080
                                        openssl pkcs12 -in C:\caddy\certificado.pfx -clcerts -nodes -out C:\caddy\certificado.crt -passin pass:Hola9080

                                        $running = $true
                                        while ($running){
                                            $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                            if(Es-PuertoValido $newPort){
                                            $puertovalido = $true
                                            Write-Host "Puerto Valido, se procederá a la configuracion"
                                            
                                            $running = $false       
                                            }else{
                                                $puertovalido = $false
                                                Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                            
                                            }
                                        }

                                        $httpsConfig = @"
:$newPort {
    tls C:/caddy/certificado.crt C:/caddy/clave.key
    root * C:/caddy/www/
    file_server
}

"@
                                    #Añade añ final del caddyfile la seccion para https
                                    Add-Content -Path "C:\caddy\Caddyfile" -Value $httpsConfig
                                    C:\caddy\caddy.exe fmt --overwrite C:\caddy\Caddyfile
                                        
                                        $running = $false
                                    }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                        $running = $false
                                    }else{
                                        Write-Host "Opcion Invalida"
                                    }   
                                }

                                Write-Host "Iniciando Servicio..."
                                try{
                                    #Start-Process -FilePath "C:\caddy\caddy.exe" -ArgumentList "caddy run" -PassThru -WindowStyle Hidden
                                    & "C:\caddy\caddy.exe" run --config C:\caddy\Caddyfile
                                    Write-Host "Servicio Iniciado con Status: "
                                    Start-Sleep -Seconds 2
                                
                                if (Get-Process caddy -ErrorAction SilentlyContinue) {
                                    Write-Host "Caddy se está ejecutando correctamente."
                                } else {
                                    Write-Host "Error al iniciar Caddy."
                                }
                                }catch {
                                    Write-Host "Error al iniciar el servicio Caddy: $($_.Exception.Message)"
                                }
                            }
                        }
                        catch{
                            echo $Error[0].ToString()
                        }
                        cd C:\Users\Administrador
                    }
                    "3"{
                        echo "Saliendo del menu de Caddy..."
                    }
                    default { echo "Selecciona una opcion valida" } 
                }
            }
            "nginx"{
                listarDirectoriosFtp -servidorFtp "$servidorFtp/Nginx"
                $nginxDescargas = "https://nginx.org/en/download.html"
                $paginaNginx = (hacerPeticion -url $nginxDescargas).Content
                $versiones = (encontrarValor -regex $versionRegex -pagina $paginaNginx)
                $versionLTSNginx = $versiones[6]
                $versionDevNginx = $versiones[0]

                echo "Instalador de Nginx"
                echo "1. Version LTS $versionLTSNginx"
                echo "2. Version de desarrollo $versionDevNginx"
                echo "3. Salir"
                $opcNginx = Read-Host "Selecciona una version"
                switch($opcNginx){
                    "1"{
                        try {
                            echo "Instalando version LTS $versionLTSNginx"
                            curl.exe "$servidorFtp/Nginx/nginx-$versionLTSNginx.zip" --ftp-ssl -k -o "C:\descargas\nginx-$versionLTSNginx.zip"
                            New-Item -Path "C:\nginx\nginx-$versionLTSNginx" -ItemType Directory -Force | Out-Null
                            
                            Expand-Archive -Path "C:\descargas\nginx-$versionLTSNginx.zip" -DestinationPath C:\nginx
                            cd C:\nginx\nginx-$versionLTSNginx\

                            $nginxconfig = "C:\nginx\nginx-$versionLTSNginx\conf\nginx.conf"
                            $configcontent = Get-Content $nginxconfig
                            #Configuramos el archivo de configuracion para cambiar el puerto
                            $configcontent = $configcontent -replace 'listen       80;', "listen       8080;"
                            Set-Content -Path $nginxconfig -Value $configcontent
                            $running = $true
                            
                            
                            #Preguntamos si queremos ssl
                            while($running){
                            Write-Host "Quieres configurar SSL para Nginx [S-N]"
                            $opc = Read-Host "Opcion"
                            if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                
                                $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                Export-PfxCertificate -Cert $cert -FilePath C:\nginx\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                Export-Certificate -Cert $cert -FilePath "C:\nginx\certificado.crt"
                                #Crea los archivos que necesita nginx a partir del certificado
                                openssl pkcs12 -in C:\nginx\certificado.pfx -clcerts -nokeys -out C:\nginx\clave.pem -passin pass:Hola9080
                                openssl pkcs12 -in C:\nginx\certificado.pfx -nocerts -nodes -out C:\nginx\clave.key -passin pass:Hola9080

                                $running = $true
                                while ($running){
                                    #Pide un puerto para https
                                    $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                    if(Es-PuertoValido -newPort $newPort){
                                    $puertovalido = $true
                                    Write-Host "Puerto Valido, se procederá a la configuracion"
                                    
                                    $running = $false
                                            
                                    }else{
                                        $puertovalido = $false
                                        Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                    
                                    }
                                }

                                $nginxconfig = "C:\nginx\nginx-$versionLTSNginx\conf\nginx.conf"

                                # Lee el contenido del archivo

                                $config = Get-Content $nginxConfig -Raw

                            # Definir la nueva configuración HTTPS
                                $newHttpsConfig = @"
server {
    listen $newPort ssl;
    server_name localhost;

    ssl_certificate C:\\nginx\clave.pem;
    ssl_certificate_key C:\\nginx\clave.key;

    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;

    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        root html;
        index index.html index.htm;
    }
}
"@

                            # Edita el arhivo de configuracion para descomentar la seccion de httos y añadir el puerto y la ruta de los certificados
                                $config = $config -replace '(?s)# HTTPS server.*?}', "# HTTPS server`r`n$newHttpsConfig"
                                $config | Set-Content -Path $nginxconfig

                                $running = $false
                            }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                $running = $false
                            }else{
                                Write-Host "Opcion Invalida"
                            }
                        }
                            
                        Start-Process -FilePath ("C:\nginx\nginx-" + $versionLTSNginx + "\nginx.exe") -WindowStyle Hidden
                        #Ya jala nomas falta iniciar el servicio mañana le das al ftp primero y luego vuelves acá
                        #& "C:\nginx\nginx-$version\nginx.exe"
                        cd C:\Users\Administrador
                        }
                        catch {
                            Echo $Error[0].ToString()
                        }
                    }
                    "2"{
                        try {
                            
                            Stop-Process -Name nginx -ErrorAction SilentlyContinue
                            echo "Instalando version LTS $versionDevNginx"
                            curl.exe "$servidorFtp/Nginx/nginx-$versionDevNginx.zip" --ftp-ssl -k -o "C:\descargas\nginx-$versionDevNginx.zip"
                            New-Item -Path "C:\nginx\nginx-$versionDevNginx" -ItemType Directory -Force | Out-Null
                            
                            Expand-Archive -Path "C:\descargas\nginx-$versionDevNginx.zip" -DestinationPath C:\nginx
                            cd C:\nginx\nginx-$versionDevNginx\

                            $nginxconfig = "C:\nginx\nginx-$versionDevNginx\conf\nginx.conf"
                            $configcontent = Get-Content $nginxconfig
                            #Configuramos el archivo de configuracion para cambiar el puerto
                            $configcontent = $configcontent -replace 'listen       80;', "listen       8080;"
                            Set-Content -Path $nginxconfig -Value $configcontent
                            $running = $true
                            
                            
                            #Preguntamos si queremos ssl
                            while($running){
                            Write-Host "Quieres configurar SSL para Nginx [S-N]"
                            $opc = Read-Host "Opcion"
                            if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                
                                $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                Export-PfxCertificate -Cert $cert -FilePath C:\nginx\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                Export-Certificate -Cert $cert -FilePath "C:\nginx\certificado.crt"
                                #Crea los archivos que necesita nginx a partir del certificado
                                openssl pkcs12 -in C:\nginx\certificado.pfx -clcerts -nokeys -out C:\nginx\clave.pem -passin pass:Hola9080
                                openssl pkcs12 -in C:\nginx\certificado.pfx -nocerts -nodes -out C:\nginx\clave.key -passin pass:Hola9080

                                $running = $true
                                while ($running){
                                    #Pide un puerto para https
                                    $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                    if(Es-PuertoValido -newPort $newPort){
                                    $puertovalido = $true
                                    Write-Host "Puerto Valido, se procederá a la configuracion"
                                    
                                    $running = $false
                                            
                                    }else{
                                        $puertovalido = $false
                                        Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                    
                                    }
                                }

                                $nginxconfig = "C:\nginx\nginx-$versionDevNginx\conf\nginx.conf"

                                # Lee el contenido del archivo

                                $config = Get-Content $nginxConfig -Raw

                            # Definir la nueva configuración HTTPS
                                $newHttpsConfig = @"
server {
    listen $newPort ssl;
    server_name localhost;

    ssl_certificate C:\\nginx\clave.pem;
    ssl_certificate_key C:\\nginx\clave.key;

    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;

    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        root html;
        index index.html index.htm;
    }
}
"@

                            # Edita el arhivo de configuracion para descomentar la seccion de httos y añadir el puerto y la ruta de los certificados
                                $config = $config -replace '(?s)# HTTPS server.*?}', "# HTTPS server`r`n$newHttpsConfig"
                                $config | Set-Content -Path $nginxconfig

                                $running = $false
                            }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                $running = $false
                            }else{
                                Write-Host "Opcion Invalida"
                            }
                        }
                            
                        Start-Process -FilePath ("C:\nginx\nginx-" + $versionDevNginx + "\nginx.exe") -WindowStyle Hidden
                        #Ya jala nomas falta iniciar el servicio mañana le das al ftp primero y luego vuelves acá
                        #& "C:\nginx\nginx-$version\nginx.exe"
                        cd C:\Users\Administrador
                        }
                        catch {
                            echo $Error[0].ToString()
                        }
                    }
                    "3"{
                        echo "Saliendo del menu de Nginx..."
                    }
                }
            }
            default{
                if(Test-Path "C:\FTP\LocalUser\Public\$opc"){
                    echo "Archivos disponibles para descarga"
                    listarDirectoriosFtp -servidorFtp "$servidorFtp/$opc"
                    $archivoADescargar = Read-Host "Selecciona uno, al seleccionar incluye tanto el nombre como la extension en caso de necesitarse"
                    if(Es-ArchivoExistente -rutaDirectorio "C:\FTP\LocalUser\Public\$opc\$archivoADescargar" -archivoABuscar $archivoADescargar){
                        echo "Archivo encontrado, comenzando con la descarga..."
                        curl.exe "$servidorFtp/$opc/$archivoADescargar" --ftp-ssl -k -o "C:\descargas\$archivoADescargar"
                    }
                    else{
                        echo "El archivo no existe en el directorio, ingresa un archivo valido"
                    }
                }
                else{
                    echo "El directorio no existe"
                }
            }
        }
    }
}

elseif($opcDescarga.ToLower() -eq "web"){
    while($true){
    echo "Menu de instalacion Web"
    echo "Elige el servicio a instalar"
    echo "1. IIS"
    echo "2. Caddy"
    echo "3. Nginx"
    echo "4. Salir"
    $opc = Read-Host "Selecciona una opcion"

    if($opc -eq "4"){
        echo "Saliendo..."
        break
    }

    switch($opc){
        "1"{
            if(-not(Get-WindowsFeature -Name Web-Server).Installed){
                $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                if(-not(Es-Numerico -string $puerto)){
                    echo "Ingresa un valor numerico entero"
                }
                elseif(-not(Es-RangoValido $puerto)){
                    echo "Ingresa un puerto dentro del rango (0-65535)"
                }
                elseif(Es-PuertoEnUso $puerto){
                    echo "El puerto se encuentra en uso"
                }
                elseif(-not(Es-PuertoValido $puerto)){
                    echo "Error el puerto no es valido"
                }
                else{
                    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
                    $opc = Read-Host "Quieres habilitar SSL? (si/no)"
                    if($opc.ToLower() -eq "si"){
                        Import-Module WebAdministration
                        $thumbprint = "96D9BFD93676F3BC2E9F54D9138C4C92801EB6DD"
                        $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumbprint }
                        New-WebBinding -Name "Default Web Site" -IP "*" -Port $puerto -Protocol https
                        $cert | New-Item -path IIS:\SslBindings\0.0.0.0!$puerto
                        netsh advfirewall firewall add rule name="IIS" dir=in action=allow protocol=TCP localport=$puerto
                        echo "IIS Se ha instalado correctamente"
                    }
                    elseif($opc.ToLower() -eq "no"){
                        Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" -PropertyName "bindingInformation" -Value ("*:" + $puerto + ":")
                        netsh advfirewall firewall add rule name="IIS" dir=in action=allow protocol=TCP localport=$puerto
                        iisreset
                        echo "IIS Se ha instalado correctamente"
                    }
                    else{
                        echo "Selecciona una opcion valida (si/no)"
                    }
                }
            }
            else{
                echo "IIS ya se encuentra instalado"
            }
        }
        "2"{
            $objetosCaddy = Invoke-RestMethod "https://api.github.com/repos/caddyserver/caddy/releases"
            $versionesCaddy = $objetosCaddy
            $versionDesarrolloCaddy = $versionesCaddy[0].tag_name
            $versionLTSCaddy = $versionesCaddy[6].tag_name


            echo "Instalador de Caddy"
            echo "1. Version LTS $versionLTSCaddy"
            echo "2. Version de desarrollo $versionDesarrolloCaddy"
            echo "3. Salir"
            $opcCaddy = Read-Host "Selecciona una version"
            switch($opcCaddy){
                "1"{
                    try{
                        $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                        if(-not(Es-Numerico -string $puerto)){
                            echo "Ingresa un valor numerico entero"
                        }
                        elseif(-not(Es-RangoValido $puerto)){
                            echo "Ingresa un puerto dentro del rango (0-65535)"
                        }
                        elseif(Es-PuertoEnUso $puerto){
                            echo "El puerto se encuentra en uso"
                        }
                        elseif(-not(Es-PuertoValido $puerto)){
                            echo "Error"
                        }
                        else{

                            Stop-Process -Name caddy -ErrorAction SilentlyContinue
                            $versionSinV = quitarPrimerCaracter -string $versionLTSCaddy
                            echo $versionSinV
                            echo "Instalando version LTS $versionLTSCaddy"
                            Invoke-WebRequest -UseBasicParsing "https://github.com/caddyserver/caddy/releases/download/$versionLTSCaddy/caddy_${versionSinV}_windows_amd64.zip" -Outfile "C:\descargas\caddy-$versionLTSCaddy.zip"
                            
                            Expand-Archive -Path "C:\descargas\caddy-$versionLTSCaddy.zip" -DestinationPath C:\caddy
                            cd C:\caddy
                            New-Item -Path "C:\caddy\www\" -ItemType "Directory"

                            #creo un archivo html que mostrara el servicio al conectarnos
                            New-Item -Path "C:\caddy\www\" -Name "index.html" -ItemType "File"
                            $HTMLcontent = @"
<html>
    <h1>Caddy LTS desde la Web</h1>
</html>
"@

                            #Creo el caddyfile y añado la configuracion inicial
                            $HTMLcontent | Out-File -Encoding utf8 -FilePath "C:\caddy\www\index.html"
                            $CaddyfileContent = @"
{
    auto_https off
}

:$puerto {
    root * C:/caddy/www/
    file_server
}

"@
                            $CaddyfileContent | Out-File -Encoding utf8 -FilePath "C:\caddy\Caddyfile"
                            C:\caddy\caddy.exe fmt --overwrite

                            $running = $true

                            #Pregunta para activar el ssl 
                            while($running){
                                Write-Host "Quieres configurar SSL para Caddy [S-N]"
                                $opc = Read-Host "Opcion"
                                if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                    
                                    $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                    Export-PfxCertificate -Cert $cert -FilePath C:\caddy\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                    Export-Certificate -Cert $cert -FilePath "C:\caddy\certificado.crt"
                                    openssl pkcs12 -in C:\caddy\certificado.pfx -nocerts -nodes -out C:\caddy\clave.key -passin pass:Hola9080
                                    openssl pkcs12 -in C:\caddy\certificado.pfx -clcerts -nodes -out C:\caddy\certificado.crt -passin pass:Hola9080

                                    $running = $true
                                    while ($running){
                                        $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                        if(Es-PuertoValido $newPort){
                                        $puertovalido = $true
                                        Write-Host "Puerto Valido, se procederá a la configuracion"
                                        
                                        $running = $false       
                                        }else{
                                            $puertovalido = $false
                                            Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                        
                                        }
                                    }

                                    $httpsConfig = @"
:$newPort {
    tls C:/caddy/certificado.crt C:/caddy/clave.key
    root * C:/caddy/www/
    file_server
}

"@
                                #Añade añ final del caddyfile la seccion para https
                                Add-Content -Path "C:\caddy\Caddyfile" -Value $httpsConfig
                                C:\caddy\caddy.exe fmt --overwrite C:\caddy\Caddyfile
                                    
                                    $running = $false
                                }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                    $running = $false
                                }else{
                                    Write-Host "Opcion Invalida"
                                }   
                            }

                            Write-Host "Iniciando Servicio..."
                            try{
                                #Start-Process -FilePath "C:\caddy\caddy.exe" -ArgumentList "caddy run" -PassThru -WindowStyle Hidden
                                & "C:\caddy\caddy.exe" run --config C:\caddy\Caddyfile
                                Write-Host "Servicio Iniciado con Status: "
                                Start-Sleep -Seconds 2
                            
                            if (Get-Process caddy -ErrorAction SilentlyContinue) {
                                Write-Host "Caddy se está ejecutando correctamente."
                            } else {
                                Write-Host "Error al iniciar Caddy."
                            }
                            }catch {
                                Write-Host "Error al iniciar el servicio Caddy: $($_.Exception.Message)"
                            }
                        }
                        }
                    catch {
                            echo $Error[0].ToString()
                    }
                    cd C:\Users\Administrador
                }
                "2"{
                    try{
                        $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                        if(-not(Es-Numerico -string $puerto)){
                            echo "Ingresa un valor numerico entero"
                        }
                        elseif(-not(Es-RangoValido $puerto)){
                            echo "Ingresa un puerto dentro del rango (0-65535)"
                        }
                        elseif(Es-PuertoEnUso $puerto){
                            echo "El puerto se encuentra en uso"
                        }
                        elseif(-not(Es-PuertoValido $puerto)){
                            echo "Error"
                        }
                        else{ 
                            Stop-Process -Name caddy -ErrorAction SilentlyContinue
                            $versionSinV = quitarPrimerCaracter -string $versionDesarrolloCaddy
                            echo $versionSinV
                            echo "Instalando version LTS $versionDesarrolloCaddy"
                            Invoke-WebRequest -UseBasicParsing "https://github.com/caddyserver/caddy/releases/download/$versionDesarrolloCaddy/caddy_${versionSinV}_windows_amd64.zip" -Outfile "C:\descargas\caddy-$versionDesarrolloCaddy.zip"
                            
                            Expand-Archive -Path "C:\descargas\caddy-$versionDesarrolloCaddy.zip" -DestinationPath C:\caddy
                            cd C:\caddy
                            New-Item -Path "C:\caddy\www\" -ItemType "Directory"

                            #creo un archivo html que mostrara el servicio al conectarnos
                            New-Item -Path "C:\caddy\www\" -Name "index.html" -ItemType "File"
                            $HTMLcontent = @"
<html>
<h1>Caddy de Desarrollo desde FTP</h1>
</html>
"@

                            #Creo el caddyfile y añado la configuracion inicial
                            $HTMLcontent | Out-File -Encoding utf8 -FilePath "C:\caddy\www\index.html"
                            $CaddyfileContent = @"
{
auto_https off
}

:$puerto {
root * C:/caddy/www/
file_server
}

"@
                            $CaddyfileContent | Out-File -Encoding utf8 -FilePath "C:\caddy\Caddyfile"
                            C:\caddy\caddy.exe fmt --overwrite

                            $running = $true

                            #Pregunta para activar el ssl 
                            while($running){
                                Write-Host "Quieres configurar SSL para Caddy [S-N]"
                                $opc = Read-Host "Opcion"
                                if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                    
                                    $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                    Export-PfxCertificate -Cert $cert -FilePath C:\caddy\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                    Export-Certificate -Cert $cert -FilePath "C:\caddy\certificado.crt"
                                    openssl pkcs12 -in C:\caddy\certificado.pfx -nocerts -nodes -out C:\caddy\clave.key -passin pass:Hola9080
                                    openssl pkcs12 -in C:\caddy\certificado.pfx -clcerts -nodes -out C:\caddy\certificado.crt -passin pass:Hola9080

                                    $running = $true
                                    while ($running){
                                        $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                        if(Es-PuertoValido $newPort){
                                        $puertovalido = $true
                                        Write-Host "Puerto Valido, se procederá a la configuracion"
                                        
                                        $running = $false       
                                        }else{
                                            $puertovalido = $false
                                            Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                        
                                        }
                                    }

                                    $httpsConfig = @"
:$newPort {
tls C:/caddy/certificado.crt C:/caddy/clave.key
root * C:/caddy/www/
file_server
}

"@
                                #Añade añ final del caddyfile la seccion para https
                                Add-Content -Path "C:\caddy\Caddyfile" -Value $httpsConfig
                                C:\caddy\caddy.exe fmt --overwrite C:\caddy\Caddyfile
                                    
                                    $running = $false
                                }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                    $running = $false
                                }else{
                                    Write-Host "Opcion Invalida"
                                }   
                            }

                            Write-Host "Iniciando Servicio..."
                            try{
                                #Start-Process -FilePath "C:\caddy\caddy.exe" -ArgumentList "caddy run" -PassThru -WindowStyle Hidden
                                & "C:\caddy\caddy.exe" run --config C:\caddy\Caddyfile
                                Write-Host "Servicio Iniciado con Status: "
                                Start-Sleep -Seconds 2
                            
                            if (Get-Process caddy -ErrorAction SilentlyContinue) {
                                Write-Host "Caddy se está ejecutando correctamente."
                            } else {
                                Write-Host "Error al iniciar Caddy."
                            }
                            }catch {
                                Write-Host "Error al iniciar el servicio Caddy: $($_.Exception.Message)"
                            }
                        }
                    }
                    catch{
                        echo $Error[0].ToString()
                    }
                    cd C:\Users\Administrador          
                }
                "3"{
                    echo "Saliendo del menu de caddy..."
                }
                default {"Selecciona una opcion dentro del rango (1..3)"}
            }
        }
        "3"{
            $nginxDescargas = "https://nginx.org/en/download.html"
            $paginaNginx = (hacerPeticion -url $nginxDescargas).Content
            $versiones = (encontrarValor -regex $versionRegex -pagina $paginaNginx)
            $versionLTSNginx = $versiones[6]
            $versionDevNginx = $versiones[0]

            echo "Instalador de Nginx"
            echo "1. Version LTS $versionLTSNginx"
            echo "2. Version de desarrollo $versionDevNginx"
            echo "3. Salir"
            $opcNginx = Read-Host "Selecciona una version"
            switch($opcNginx){
                "1"{
                    try {
                        $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                        if(-not(Es-Numerico -string $puerto)){
                            echo "Ingresa un valor numerico entero"
                        }
                        elseif(-not(Es-RangoValido $puerto)){
                            echo "Ingresa un puerto dentro del rango (0-65535)"
                        }
                        elseif(Es-PuertoEnUso $puerto){
                            echo "El puerto se encuentra en uso"
                        }
                        elseif(-not(Es-PuertoValido $puerto)){
                            echo "Error"
                        }
                        else{

                            Stop-Process -Name nginx -ErrorAction SilentlyContinue
                            echo "Instalando version LTS $versionLTSNginx"
                            Invoke-WebRequest -UseBasicParsing "https://nginx.org/download/nginx-$versionLTSNginx.zip" -Outfile "C:\descargas\nginx-$versionLTSNginx.zip"
                            New-Item -Path "C:\nginx\nginx-$versionLTSNginx" -ItemType Directory -Force | Out-Null
                            
                            Expand-Archive -Path "C:\descargas\nginx-$versionLTSNginx.zip" -DestinationPath C:\nginx
                            cd C:\nginx\nginx-$versionLTSNginx\

                            $nginxconfig = "C:\nginx\nginx-$versionLTSNginx\conf\nginx.conf"
                            $configcontent = Get-Content $nginxconfig
                            #Configuramos el archivo de configuracion para cambiar el puerto
                            $configcontent = $configcontent -replace 'listen       80;', "listen       $puerto;"
                            Set-Content -Path $nginxconfig -Value $configcontent
                            $running = $true
                            
                            
                            #Preguntamos si queremos ssl
                            while($running){
                                Write-Host "Quieres configurar SSL para Nginx [S-N]"
                                $opc = Read-Host "Opcion"
                                if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                    
                                    $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                    Export-PfxCertificate -Cert $cert -FilePath C:\nginx\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                    Export-Certificate -Cert $cert -FilePath "C:\nginx\certificado.crt"
                                    #Crea los archivos que necesita nginx a partir del certificado
                                    openssl pkcs12 -in C:\nginx\certificado.pfx -clcerts -nokeys -out C:\nginx\clave.pem -passin pass:Hola9080
                                    openssl pkcs12 -in C:\nginx\certificado.pfx -nocerts -nodes -out C:\nginx\clave.key -passin pass:Hola9080

                                    $running = $true
                                    while ($running){
                                        #Pide un puerto para https
                                        $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                        if(Es-PuertoValido -newPort $newPort){
                                        $puertovalido = $true
                                        Write-Host "Puerto Valido, se procederá a la configuracion"
                                        
                                        $running = $false
                                                
                                        }else{
                                            $puertovalido = $false
                                            Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                        
                                        }
                                    }

                                    $nginxconfig = "C:\nginx\nginx-$versionLTSNginx\conf\nginx.conf"

                                    # Lee el contenido del archivo

                                    $config = Get-Content $nginxConfig -Raw

                                    # Definir la nueva configuración HTTPS
                                    $newHttpsConfig = @"
server {
    listen $newPort ssl;
    server_name localhost;

    ssl_certificate C:\\nginx\clave.pem;
    ssl_certificate_key C:\\nginx\clave.key;

    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;

    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        root html;
        index index.html index.htm;
    }
}
"@

                                    # Edita el arhivo de configuracion para descomentar la seccion de httos y añadir el puerto y la ruta de los certificados
                                    $config = $config -replace '(?s)# HTTPS server.*?}', "# HTTPS server`r`n$newHttpsConfig"
                                    $config | Set-Content -Path $nginxconfig

                                    $running = $false
                                }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                    $running = $false
                                }else{
                                    Write-Host "Opcion Invalida"
                                }
                            }
                            
                            Start-Process -FilePath ("C:\nginx\nginx-" + $versionLTSNginx + "\nginx.exe") -WindowStyle Hidden
                            #Ya jala nomas falta iniciar el servicio mañana le das al ftp primero y luego vuelves acá
                            #& "C:\nginx\nginx-$version\nginx.exe"
                            cd C:\Users\Administrador
                        }
                    }catch {
                            Echo $Error[0].ToString()
                    }
                }
                "2"{
                    try {
                        $puerto = Read-Host "Ingresa el puerto donde se realizara la instalacion"
                        if(-not(Es-Numerico -string $puerto)){
                            echo "Ingresa un valor numerico entero"
                        }
                        elseif(-not(Es-RangoValido $puerto)){
                            echo "Ingresa un puerto dentro del rango (0-65535)"
                        }
                        elseif(Es-PuertoEnUso $puerto){
                            echo "El puerto se encuentra en uso"
                        }
                        elseif(-not(Es-PuertoValido $puerto)){
                            echo "Error"
                        }
                        else{
                            Stop-Process -Name nginx -ErrorAction SilentlyContinue
                            echo "Instalando version LTS $versionDevNginx"
                            Invoke-WebRequest -UseBasicParsing "https://nginx.org/download/nginx-$versionDevNginx.zip" -Outfile "C:\descargas\nginx-$versionDevNginx.zip"
                            
                            Expand-Archive -Path "C:\descargas\nginx-$versionDevNginx.zip" -DestinationPath C:\nginx
                            cd C:\nginx\nginx-$versionDevNginx\

                            $nginxconfig = "C:\nginx\nginx-$versionDevNginx\conf\nginx.conf"
                            $configcontent = Get-Content $nginxconfig
                            #Configuramos el archivo de configuracion para cambiar el puerto
                            $configcontent = $configcontent -replace 'listen       80;', "listen       $puerto;"
                            Set-Content -Path $nginxconfig -Value $configcontent
                            $running = $true
                            
                            
                            #Preguntamos si queremos ssl
                            while($running){
                                Write-Host "Quieres configurar SSL para Nginx [S-N]"
                                $opc = Read-Host "Opcion"
                                if($opc.ToLower() -eq "s" -or $opc.ToLower() -eq "si"){
                                    
                                    $cert = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*CN=ftp.PruebaFTP.com*" } | Sort-Object NotAfter -Descending | Select-Object -First 1
                                    Export-PfxCertificate -Cert $cert -FilePath C:\nginx\certificado.pfx -Password (ConvertTo-SecureString -String "Hola9080" -Force -AsPlainText)
                                    Export-Certificate -Cert $cert -FilePath "C:\nginx\certificado.crt"
                                    #Crea los archivos que necesita nginx a partir del certificado
                                    openssl pkcs12 -in C:\nginx\certificado.pfx -clcerts -nokeys -out C:\nginx\clave.pem -passin pass:Hola9080
                                    openssl pkcs12 -in C:\nginx\certificado.pfx -nocerts -nodes -out C:\nginx\clave.key -passin pass:Hola9080

                                    $running = $true
                                    while ($running){
                                        #Pide un puerto para https
                                        $newPort = Read-Host "Introduce el puerto para HTTPS de el servicio"
                                        if(Es-PuertoValido -newPort $newPort){
                                        $puertovalido = $true
                                        Write-Host "Puerto Valido, se procederá a la configuracion"
                                        
                                        $running = $false
                                                
                                        }else{
                                            $puertovalido = $false
                                            Write-Host "Puerto invalido o está en uso ingresa otro dato"
                                        
                                        }
                                    }

                                    $nginxconfig = "C:\nginx\nginx-$versionDevNginx\conf\nginx.conf"

                                    # Lee el contenido del archivo

                                    $config = Get-Content $nginxConfig -Raw

                                    # Definir la nueva configuración HTTPS
                                    $newHttpsConfig = @"
server {
    listen $newPort ssl;
    server_name localhost;

    ssl_certificate C:\\nginx\clave.pem;
    ssl_certificate_key C:\\nginx\clave.key;

    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 5m;

    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        root html;
        index index.html index.htm;
    }
}
"@

                                    # Edita el arhivo de configuracion para descomentar la seccion de httos y añadir el puerto y la ruta de los certificados
                                    $config = $config -replace '(?s)# HTTPS server.*?}', "# HTTPS server`r`n$newHttpsConfig"
                                    $config | Set-Content -Path $nginxconfig

                                    $running = $false
                                }elseif($opc.ToLower() -eq "no" -or $opc.ToLower() -eq "n"){
                                    $running = $false
                                }else{
                                    Write-Host "Opcion Invalida"
                                }
                            }
                            
                            Start-Process -FilePath ("C:\nginx\nginx-" + $versionDevNginx + "\nginx.exe") -WindowStyle Hidden
                            #Ya jala nomas falta iniciar el servicio mañana le das al ftp primero y luego vuelves acá
                            #& "C:\nginx\nginx-$version\nginx.exe"
                            cd C:\Users\Administrador
                        }
                    }catch {
                        Echo $Error[0].ToString()
                    }
                }
                "3"{
                    echo "Saliendo del menu de Nginx..."
                }
                default {"Selecciona una opcion dentro del rango (1..3)"}
            }
        }
        default {echo "Selecciona una opcion dentro del rango (1..4)"}
    }
    echo `n
    }
}
else{
    echo "Selecciona una opcion valida (web/ftp)"
}