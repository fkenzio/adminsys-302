function Configure-FTPServer {
    param(
        [string]$FTPSiteName = 'FTP Site',
        [string]$FTPDir = 'C:\FTPRoot',
        [int]$FTPPort = 21
    )

    Import-Module WebAdministration

    # Verificar si IIS está instalado
    if (-not (Get-WindowsFeature -Name Web-Server).Installed) {
        Install-WindowsFeature Web-Server -IncludeManagementTools -Verbose
    } else {
        Write-Host "IIS ya está instalado."
    }

    # Verificar si la característica Web-FTP-Server está instalada
    if (-not (Get-WindowsFeature -Name Web-FTP-Server).Installed) {
        Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature -Verbose
    } else {
        Write-Host "FTP Server ya está instalado."
    }


    # Validar que el directorio raíz exista, si no, crearlo
    if (-not (Test-Path $FTPDir)) {
        New-Item -ItemType Directory -Force -Path $FTPDir
    } else {
        Write-Host "El directorio raíz FTP '$FTPDir' ya existe."
    }

    # Validar que el puerto esté disponible (puerto 21)
    $portInUse = Test-NetConnection -ComputerName 'localhost' -Port $FTPPort
    if ($portInUse.TcpTestSucceeded) {
        Write-Host "El puerto $FTPPort ya está en uso, eligiendo otro puerto..."
        $FTPPort = 2121 # Cambiar al puerto alternativo 2121 si está ocupado
    } else {
        Write-Host "Puerto $FTPPort disponible para usar."
    }

    # Crear el sitio FTP si no existe
    $existingFtpSite = Get-Website | Where-Object { $_.Name -eq $FTPSiteName -and $_.PhysicalPath -eq $FTPDir }
    if ($existingFtpSite) {
        Write-Host "El sitio FTP '$FTPSiteName' ya existe."
    } else {
        New-WebFtpSite -Name $FTPSiteName -Port $FTPPort -PhysicalPath $FTPDir -Force
        Write-Host "Sitio FTP '$FTPSiteName' creado exitosamente."
    }
}

function Habilitar-SSL(){
    param (
        [string]$numeroCert
    )

    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.security.ssl.serverCertHash -Value $numeroCert
    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.security.ssl.controlChannelPolicy -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.security.ssl.dataChannelPolicy -Value "SslAllow"
}

function generar-certificado(){
    param (
        [string]$DnsName = "WIN-AC2DN26G1LP"  # Nombre del servidor FTP
    )

    # Generar el certificado auto-firmado
    $cert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation "Cert:\LocalMachine\My"

    # Mover el certificado a la lista de certificados confiables (Root)
    $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $rootStore.Open("ReadWrite")
    $rootStore.Add($cert)
    $rootStore.Close()

    # Mostrar información del certificado
    Write-Output "Certificado generado exitosamente"
    Write-Output "Nombre: $($cert.Subject)"
    Write-Output "Thumbprint: $($cert.Thumbprint)"
    Write-Output "Expira el: $($cert.NotAfter)"
    
    # Devolver el Thumbprint del certificado
    return $cert.Thumbprint
}

function listar-Carpetas-FTP {
    param (
        [string]$servidorFtp
    )

    $usuario = "anonymous"
    $contrasena = ""

    $conexion = $false

    $validacionOriginalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

    foreach ($usar_SSL in $false, $true) {
        try {
            $peticion = [System.Net.FtpWebRequest]::Create($servidorFtp)
            $peticion.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
            $peticion.Credentials = New-Object System.Net.NetworkCredential($usuario, $contrasena)
            $peticion.EnableSsl = $usar_SSL

            if ($usar_SSL) {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            }

            $respuesta = $peticion.GetResponse()
            $respuestaStream = $respuesta.GetResponseStream()
            $lector = New-Object System.IO.StreamReader($respuestaStream)

            Write-Host "Conexion exitosa con SSL = $usar_SSL"

            while (-not $lector.EndOfStream) {
                $linea = $lector.ReadLine()
                Write-Output $linea
            }

            $lector.Close()
            $respuestaStream.Close()
            $respuesta.Close()

            $conexion = $true
            break
        }
        catch {
            Write-Host "Fallo la conexión con SSL = $usar_SSL, reintentando nuevamente..."
        }
    }

    if (-not $conexion) {
        Write-Host "No se pudo conectar al FTP con o sin certificado SSL."
    }

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $validacionOriginalCallback
}

