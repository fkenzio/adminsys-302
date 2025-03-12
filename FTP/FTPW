function instalarFTP {
    Install-WindowsFeature Web-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Service -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-Basic-Auth
    new-netfirewallrule -displayname "FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action allow
    New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath C:\FTP
    Set-ItemProperty "IIS:\\Sites\\FTP" -name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\\Sites\\FTP" -name ftpServer.security.ssl.dataChannelPolicy -Value 0
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"
    if(-not(test-path C:\FTP)){
        mkdir C:\FTP
        mkdir C:\FTP\General
        mkdir C:\FTP\LocalUser
        mkdir C:\FTP\LocalUser\Public
        New-Item -ItemType SymbolicLink -Path "C:\FTP\LocalUser\Public\General" -Target "C:\FTP\General"
    }
}

function CrearGrupos {
    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"
    
    if(-not($ADSI.Children | Where-Object { $.SchemaClassName -eq "Group" -and $.Name -eq "Reprobados"})){  
        mkdir C:\FTP\Reprobados
        $FTPUserGroup = $ADSI.Create("Group", "Reprobados")
        $FTPUserGroup.Description = "Los miembros de este grupo están Reprobados"
        $FTPUserGroup.SetInfo()
    }
    
    if(-not($ADSI.Children | Where-Object { $.SchemaClassName -eq "Group" -and $.Name -eq "Recursadores"})){  
        mkdir C:\FTP\Recursadores
        $FTPUserGroup = $ADSI.Create("Group", "Recursadores")
        $FTPUserGroup.Description = "Los miembros de este grupo están Recursando"
        $FTPUserGroup.SetInfo()
    }
}

# Lista global de usuarios creados
$Global:ListaUsuarios = @()

function CrearUsuario {
    while ($true) {
        $nombre = Read-Host "Ingrese el nombre de usuario (3-20 caracteres, solo letras, números o '_') o 'salir' para finalizar"
        if ($nombre -eq "salir") {
            Write-Host "Fin de creación de usuarios."
            return
        }

        if (-not ($nombre -match "^[a-zA-Z0-9_]{3,20}$")) {
            Write-Host "Error: Nombre inválido. Debe contener entre 3 y 20 caracteres válidos." -ForegroundColor Red
            continue
        }

        if (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue) {
            Write-Host "Error: El usuario '$nombre' ya existe." -ForegroundColor Red
            continue
        }

        do {
            $password = Read-Host "Ingrese una contraseña (mínimo 8 caracteres, incluyendo mayúsculas, minúsculas, números y especiales)"

            if ($password.Length -ge 8 -and 
                $password -match "[A-Z]" -and 
                $password -match "[a-z]" -and 
                $password -match "[0-9]" -and 
                $password -match "[^a-zA-Z0-9]") {
                $securePass = ConvertTo-SecureString $password -AsPlainText -Force
                break
            }
            else {
                Write-Host "Error: La contraseña no cumple los requisitos. Intente de nuevo." -ForegroundColor Red
            }
        } while ($true)

        Write-Host "Seleccione el grupo al que pertenecerá el usuario:"
        $opcion = Read-Host "1-Reprobados  2-Recursadores"
        $grupo = switch ($opcion) {
            "1" { "Reprobados" }
            "2" { "Recursadores" }
            default { "" }
        }

        if ($grupo -eq "") {
            Write-Host "Error: Grupo inválido." -ForegroundColor Red
            continue
        }

        New-LocalUser -Name $nombre -Password $securePass -FullName $nombre -Description "Usuario FTP"
        Add-LocalGroupMember -Group $grupo -Member $nombre

        $carpetaUsuario = "C:\FTP\LocalUser\$nombre"
        if (-not (Test-Path $carpetaUsuario)) {
            New-Item -Path $carpetaUsuario -ItemType Directory | Out-Null
            New-Item -Path "$carpetaUsuario\$nombre" -ItemType Directory | Out-Null
            New-Item -ItemType SymbolicLink -Path "$carpetaUsuario\General" -Target "C:\FTP\General" -ErrorAction SilentlyContinue
            New-Item -ItemType SymbolicLink -Path "$carpetaUsuario\$grupo" -Target "C:\FTP\$grupo" -ErrorAction SilentlyContinue
        }

        $Global:ListaUsuarios += [PSCustomObject]@{
            Nombre = $nombre
            Grupo  = $grupo
        }

        Write-Host "Usuario '$nombre' creado exitosamente." -ForegroundColor Green
    }
}

# Main Script Execution
Clear-Host
Write-Host "Iniciando instalación del servidor FTP."
instalarFTP
Write-Host "Creando los grupos."
CrearGrupos
Write-Host "Creando usuario(s)."
CrearUsuario
Write-Host "Configuración completada."