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
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
    
    # Aislar directorios de usuario para mayor seguridad
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"
    
    # Habilitar autenticación básica y permitir acceso a usuarios locales
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    
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
    # Asignar permisos de solo lectura a la carpeta de acceso anónimo
    icacls "C:\FTP\General" /grant "IUSR:(OI)(CI)R" /T /C | Out-Null
    
    # Configurar reglas de autorización en IIS para acceso anónimo solo lectura
    if (-not (Get-WebConfiguration "/system.ftpServer/security/authorization" | Where-Object { $_.Attributes["users"].Value -eq "*" })) {
        add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=1}
    }
}

function CrearGrupos {
    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
    
    if (-not ($ADSI.Children | Where-Object { $.SchemaClassName -eq "Group" -and $.Name -eq "Reprobados" })) {  
        mkdir C:\FTP\Reprobados
        $FTPUserGroup = $ADSI.Create("Group", "Reprobados")
        $FTPUserGroup.Description = "Grupo de usuarios reprobados"
        $FTPUserGroup.SetInfo()
    }
    
    if (-not ($ADSI.Children | Where-Object { $.SchemaClassName -eq "Group" -and $.Name -eq "Recursadores" })) {  
        mkdir C:\FTP\Recursadores
        $FTPUserGroup = $ADSI.Create("Group", "Recursadores")
        $FTPUserGroup.Description = "Grupo de usuarios recursadores"
        $FTPUserGroup.SetInfo()
    }
}

# Validar contraseña según los requisitos
function ValidarContrasena {
    param ([string]$password)

    return ($password.Length -ge 8 -and 
            $password -match "[A-Z]" -and 
            $password -match "[\W_]" -and 
            $password -notmatch "\s")
}

# Lista global de usuarios creados
$Global:ListaUsuarios = @()

function CrearUsuario {
    while ($true) {
        $nombre = Read-Host "Ingrese el nombre de usuario (mínimo 4 letras, solo letras)"
        
        # Validación de nombre de usuario
        if ($nombre -eq "salir") {
            Write-Host "Fin de creación de usuarios."
            return
        }
        
        if ($nombre.Length -lt 4 -or $nombre -notmatch "^[a-zA-Z]+$") {
            Write-Host "Error: El nombre de usuario debe contener al menos 4 letras y solo puede contener letras." -ForegroundColor Red
            continue
        }

        if (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue) {
            Write-Host "Error: El usuario '$nombre' ya existe." -ForegroundColor Red
            continue
        }

        # Validación del grupo
        $grupo = ""
        while ($grupo -ne "Reprobados" -and $grupo -ne "Recursadores") {
            $grupo = Read-Host "Ingrese el grupo (Reprobados/Recursadores)"
            if ($grupo -ne "Reprobados" -and $grupo -ne "Recursadores") {
                Write-Host "Error: Grupo inválido. Intente nuevamente." -ForegroundColor Red
            }
        }

        # Validación de la contraseña
        while ($true) {
            $password = Read-Host "Ingrese una contraseña segura (mínimo 8 caracteres, 1 mayúscula, 1 símbolo especial, sin espacios)"

            if (ValidarContrasena $password) {
                break
            } else {
                Write-Host "Error: La contraseña no cumple con los requisitos. Intente nuevamente." -ForegroundColor Red
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
        
        $Global:ListaUsuarios += @{ Nombre = $nombre; Grupo = $grupo }
        Write-Host "Usuario '$nombre' creado exitosamente." -ForegroundColor Green
    }
}

function AplicarPermisos {
    foreach ($usr in $Global:ListaUsuarios) {
        $nombre = $usr.Nombre
        $grupo  = $usr.Grupo

        icacls "C:\FTP\LocalUser\$nombre" /grant "${nombre}:(OI)(CI)F" /T /C | Out-Null
        icacls "C:\FTP\General" /grant "${nombre}:(OI)(CI)M" | Out-Null
        icacls "C:\FTP\$grupo" /grant "${nombre}:(OI)(CI)M" | Out-Null
    }
    
    icacls "C:\FTP\General" /grant "IUSR:(OI)(CI)R" /T /C | Out-Null
    Restart-WebItem "IIS:\Sites\FTP"
}

# Ejecución Principal
Clear-Host
Write-Host "Instalando y configurando el servidor FTP..."
instalarFTP
Write-Host "Configurando acceso anónimo..."
ConfigurarAnonimo
Write-Host "Creando grupos de usuarios..."
CrearGrupos
Write-Host "Creando usuarios FTP..."
CrearUsuario
Write-Host "Aplicando permisos y configuraciones finales..."
AplicarPermisos
Write-Host "Configuración completada exitosamente."