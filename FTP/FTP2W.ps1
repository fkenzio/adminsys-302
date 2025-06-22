function instalarFTP {
    Import-Module ServerManager
    Import-Module WebAdministration

    # Instalar IIS y servicio FTP
    Install-WindowsFeature Web-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Service
    Install-WindowsFeature Web-Basic-Auth

    # Reglas de firewall
    New-NetFirewallRule -DisplayName "FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow
    New-NetFirewallRule -DisplayName "ICMPv4" -Protocol ICMPv4 -Direction Inbound -Action Allow
    New-NetFirewallRule -DisplayName "ICMPv6" -Protocol ICMPv6 -Direction Inbound -Action Allow

    # Crear estructura de directorios
    if (-not (Test-Path "C:\FTP")) {
        New-Item -Path "C:\FTP" -ItemType Directory
        New-Item -Path "C:\FTP\General" -ItemType Directory
        New-Item -Path "C:\FTP\LocalUser\Public" -ItemType Directory -Force
    }

    # Crear sitio web FTP si no existe
    if (-not (Get-Website | Where-Object { $_.Name -eq "FTP" })) {
        New-Website -Name "FTP" -PhysicalPath "C:\FTP" -Port 21 -Force
    }

    # Configurar FTP: Desactivar SSL
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/ssl" -Name "controlChannelPolicy" -Value "SslAllow"
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/ssl" -Name "dataChannelPolicy" -Value "SslAllow"

    # Aislamiento por usuario
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"

    # Habilitar autenticación básica y anónima
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
}

function ConfigurarAnonimo {
    icacls "C:\FTP\General" /grant "IUSR:(OI)(CI)R" /T /C | Out-Null

    if (-not (Get-WebConfiguration "/system.ftpServer/security/authorization" | Where-Object { $_.Attributes["users"].Value -eq "*" })) {
        Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=1}
    }
}

function CrearGrupos {
    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"

    if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Reprobados" })) {
        New-Item -Path "C:\FTP\Reprobados" -ItemType Directory
        $grupo = $ADSI.Create("Group", "Reprobados")
        $grupo.SetInfo()
    }

    if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Recursadores" })) {
        New-Item -Path "C:\FTP\Recursadores" -ItemType Directory
        $grupo = $ADSI.Create("Group", "Recursadores")
        $grupo.SetInfo()
    }
}

function CrearUsuario {
    while ($true) {
        $nombre = Read-Host "Nombre de usuario (mínimo 4 letras, solo letras, escribir 'salir' para terminar)"
        if ($nombre -eq "salir") { return }

        if ($nombre.Length -lt 4 -or $nombre -notmatch "^[a-zA-Z]+$") {
            Write-Host "Nombre inválido. Debe tener al menos 4 letras sin números ni símbolos." -ForegroundColor Red
            continue
        }

        if (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue) {
            Write-Host "El usuario ya existe." -ForegroundColor Red
            continue
        }

        $grupo = ""
        while ($grupo -ne "Reprobados" -and $grupo -ne "Recursadores") {
            $op = Read-Host "Seleccione grupo (1: Reprobados, 2: Recursadores)"
            if ($op -eq "1") { $grupo = "Reprobados" }
            elseif ($op -eq "2") { $grupo = "Recursadores" }
            else { Write-Host "Opción inválida." -ForegroundColor Red }
        }

        while ($true) {
            $pass = Read-Host "Contraseña segura (8+ caracteres, 1 mayúscula, 1 símbolo, sin espacios)"
            if ($pass.Length -ge 8 -and $pass -match "[A-Z]" -and $pass -match "[\W_]" -and $pass -notmatch "\s") {
                break
            } else {
                Write-Host "Contraseña no válida." -ForegroundColor Red
            }
        }

        New-LocalUser -Name $nombre -Password (ConvertTo-SecureString $pass -AsPlainText -Force) -FullName $nombre -Description "Usuario FTP"
        Add-LocalGroupMember -Group $grupo -Member $nombre

        $ruta = "C:\FTP\LocalUser\$nombre"
        if (-not (Test-Path $ruta)) {
            New-Item -Path "$ruta\Personal" -ItemType Directory -Force
            New-Item -Path "$ruta\General" -ItemType Junction -Target "C:\FTP\General" -Force
            New-Item -Path "$ruta\$grupo" -ItemType Junction -Target "C:\FTP\$grupo" -Force
        }

        Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users=$nombre;permissions=3}
        Write-Host "Usuario '$nombre' creado correctamente." -ForegroundColor Green
    }
}

function AplicarPermisos {
    Stop-Website -Name "FTP"
    Start-Website -Name "FTP"
}

# EJECUCIÓN PRINCIPAL
Clear-Host
Write-Host "Instalando y configurando servidor FTP..." -ForegroundColor Cyan
instalarFTP
Write-Host "Configurando acceso anónimo..." -ForegroundColor Cyan
ConfigurarAnonimo
Write-Host "Creando grupos..." -ForegroundColor Cyan
CrearGrupos
Write-Host "Creando usuarios FTP..." -ForegroundColor Cyan
CrearUsuario
Write-Host "Reiniciando sitio FTP..." -ForegroundColor Cyan
AplicarPermisos
Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green
