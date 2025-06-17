function instalarFTP {
    # Instalar IIS y servicio FTP
    Install-WindowsFeature Web-Server -IncludeAllSubFeature -Restart
    Install-WindowsFeature Web-FTP-Service -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-Basic-Auth
    
    # Configurar reglas de firewall para permitir tráfico FTP y PING
    new-netfirewallrule -displayname "FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action allow
    new-netfirewallrule -displayname "ICMPv4" -Direction Inbound -Protocol ICMPv4 -Action allow
    new-netfirewallrule -displayname "ICMPv6" -Direction Inbound -Protocol ICMPv6 -Action allow
    
    # Verificar si el sitio FTP ya existe en IIS antes de crearlo
    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath C:\FTP
    }
    
    # Configurar SSL en FTP (deshabilitado para permitir conexiones básicas)
    Set-ItemProperty "IIS:\\Sites\\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\\Sites\\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
    
    # Aislar directorios de usuario para mayor seguridad
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"
    
    # Habilitar autenticación básica y permitir acceso a usuarios locales
    Set-ItemProperty "IIS:\\Sites\\FTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\\Sites\\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    
    # Crear estructura de directorios
    if (-not(Test-Path C:\FTP)) {
        mkdir C:\FTP
        mkdir C:\FTP\General
        mkdir C:\FTP\LocalUser
        mkdir C:\FTP\LocalUser\Public
        New-Item -ItemType SymbolicLink -Path "C:\FTP\LocalUser\Public\General" -Target "C:\FTP\General"
    }
}

function ConfigurarAnonimo {
    icacls "C:\FTP\General" /grant "IUSR:(OI)(CI)R" /T /C | Out-Null
    if (-not (Get-WebConfiguration "/system.ftpServer/security/authorization" | Where-Object { $_.Attributes["users"].Value -eq "*" })) {
        add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=1}
    }
}

function CrearGrupos {
    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
    
    if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Reprobados" })) {
        mkdir C:\FTP\Reprobados
        $FTPUserGroup = $ADSI.Create("Group", "Reprobados")
        $FTPUserGroup.Description = "Usuarios con acceso restringido"
        $FTPUserGroup.SetInfo()
    }
    
    if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Recursadores" })) {
        mkdir C:\FTP\Recursadores
        $FTPUserGroup = $ADSI.Create("Group", "Recursadores")
        $FTPUserGroup.Description = "Usuarios con permisos adicionales"
        $FTPUserGroup.SetInfo()
    }
}

function CrearUsuario {
    while ($true) {
        $nombre = Read-Host "Escriba un nombre de usuario (mínimo 4 letras, solo letras)"
        
        if ($nombre -eq "salir") {
            Write-Host "Finalizando la creación de usuarios."
            return
        }
        
        if ($nombre.Length -lt 4 -or $nombre -notmatch "^[a-zA-Z]+$") {
            Write-Host "Error: Debe contener al menos 4 letras y solo puede incluir letras." -ForegroundColor Red
            continue
        }
        
        if (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue) {
            Write-Host "Error: El usuario '$nombre' ya existe." -ForegroundColor Red
            continue
        }
        
        $grupo = ""
        while ($grupo -ne "Reprobados" -and $grupo -ne "Recursadores") {
            $seleccion = Read-Host "Seleccione el grupo (1 para Reprobados, 2 para Recursadores)"
            if ($seleccion -eq "1") { $grupo = "Reprobados" }
            elseif ($seleccion -eq "2") { $grupo = "Recursadores" }
            else { Write-Host "Error: Opción inválida. Intente de nuevo." -ForegroundColor Red }
        }
        
        while ($true) {
            $password = Read-Host "Defina una contraseña segura (mínimo 8 caracteres, 1 mayúscula, 1 símbolo, sin espacios)"
            if ($password.Length -ge 8 -and $password -match "[A-Z]" -and $password -match "[\W_]" -and $password -notmatch "\s") {
                break
            } else {
                Write-Host "Error: La contraseña no cumple los requisitos. Inténtelo nuevamente." -ForegroundColor Red
            }
        }
        
        New-LocalUser -Name $nombre -Password (ConvertTo-SecureString $password -AsPlainText -Force) -FullName $nombre -Description "Usuario FTP"
        Add-LocalGroupMember -Group $grupo -Member $nombre
        
        $carpetaUsuario = "C:\FTP\LocalUser\$nombre"
        if (-not (Test-Path $carpetaUsuario)) {
            mkdir "$carpetaUsuario"
            New-Item -ItemType Directory -Path "$carpetaUsuario\Personal" | Out-Null
            New-Item -ItemType SymbolicLink -Path "$carpetaUsuario\General" -Target "C:\FTP\General"
            New-Item -ItemType SymbolicLink -Path "$carpetaUsuario\$grupo" -Target "C:\FTP\$grupo"
        }
        
        add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="$nombre";permissions=3}
        Write-Host "Usuario '$nombre' creado correctamente." -ForegroundColor Green
    }
}

function AplicarPermisos {
    Restart-WebItem "IIS:\Sites\FTP"
}

# Ejecución Principal
Clear-Host
Write-Host "Configurando servidor FTP..."
instalarFTP
Write-Host "Configurando acceso anónimo..."
ConfigurarAnonimo
Write-Host "Creando grupos..."
CrearGrupos
Write-Host "Creando usuarios FTP..."
CrearUsuario
Write-Host "Aplicando configuraciones finales..."
AplicarPermisos
Write-Host "Proceso completado."
