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


function Enabled-Autentication(){
    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true
}

function Enabled-SSL(){
    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
}

function Enabled-AccessAnonym(){
    # Habilitar autenticación anónima
    Set-ItemProperty "IIS:\Sites\FTP Site" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
}


function Restart-Site(){
    Restart-WebItem "IIS:\Sites\FTP Site"
}


function create_groups() {
    $groups = @("reprobados", "recursadores")
    $ADSI = [ADSI]"WinNT://$env:ComputerName"

    foreach ($group in $groups) {
        # Verificar si el grupo ya existe
        if ($ADSI.Children | Where-Object { $_.Name -eq $group }) {
            Write-Output "El grupo '$group' ya existe."
        } else {
            # Crear el grupo si no existe
            $FTPUserGroup = $ADSI.Create("Group", "$group")
            $FTPUserGroup.SetInfo()
            Write-Output "Grupo '$group' creado correctamente."
        }
    }
}

function create_user ([String]$Username, [String]$Password, [String]$Group) {
    $FTPUsername = $Username
    $FTPPassword = $Password
    $FTPGroup = $Group
    $ADSI = [ADSI]"WinNT://$env:ComputerName"

    # Validar la contraseña antes de crear el usuario
    if (-not(Validate-Password $FTPPassword)) {
        Write-Output "No se puede crear el usuario debido a una contraseña inválida."
        return
    }

    # Verificar si el usuario ya existe
    if ($ADSI.Children | Where-Object { $_.Name -eq $Username }) {
        Write-Output "El usuario '$Username' ya existe."
    } else {
        # Crear usuario
        $CreateFTPUser = $ADSI.Create("User", "$FTPUsername")
        $CreateFTPUser.SetInfo()
        $CreateFTPUser.SetPassword("$FTPPassword")
        $CreateFTPUser.SetInfo()

        mkdir "C:\FTPRoot\LocalUser\$FTPUsername"
        mkdir "C:\FTPRoot\Users\$FTPUsername"
        icacls "C:\FTPRoot\LocalUser\$FTPUsername" /grant "$($FTPUsername):(OI)(CI)F"
        icacls "C:\FTPRoot\LocalUser\$FTPUsername" /grant "Usuarios:(OI)(CI)M"
        icacls "C:\FTPRoot\$FTPGroup" /grant "$($FTPGroup):(OI)(CI)F"
        icacls "C:\FTPRoot\LocalUser\Public" /grant "$($FTPUsername):(OI)(CI)F"
        # icacls "C:\FTP\$FTPGroup" /grant "$($FTPUsername):(OI)(CI)F"
        New-Item -ItemType Junction -Path "C:\FTPRoot\LocalUser\$FTPUsername\Public" -Target "C:\FTPRoot\LocalUser\Public"
        icacls "C:\FTPRoot\LocalUser\$FTPUsername\Public" /grant "$($FTPUsername):(OI)(CI)F"
        New-Item -ItemType Junction -Path "C:\FTPRoot\LocalUser\$FTPUsername\$FTPUsername" -Target "C:\FTPRoot\Users\$FTPUsername"
        icacls "C:\FTPRoot\LocalUser\$FTPUsername\$FTPUsername" /grant "$($FTPUsername):(OI)(CI)F"
        New-Item -ItemType Junction -Path "C:\FTPRoot\LocalUser\$FTPUsername\$FTPGroup" -Target "C:\FTPRoot\$FTPGroup"
        icacls "C:\FTPRoot\LocalUser\$FTPUsername\$FTPGroup" /grant "$($FTPUsername):(OI)(CI)F"

        # configurar_permisos -FTPUserGroupName $FTPGroup

        Write-Output "Usuario '$Username' creado correctamente."
    }
}

function add_user_to_group([String]$Username, [String]$GroupName) {
    $UserAccount = New-Object System.Security.Principal.NTAccount($Username)
    $SID = $UserAccount.Translate([System.Security.Principal.SecurityIdentifier])
    $Group = [ADSI]"WinNT://$env:ComputerName/$GroupName,Group"
    $User = [ADSI]"WinNT://$SID"

    try {
        $Group.Add($User.Path)
        Write-Output "Usuario '$Username' agregado correctamente al grupo '$GroupName'."
    } catch {
        Write-Output "Error al agregar el usuario '$Username' al grupo '$GroupName'."
    }
}

function Change-UserGroup {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username,
        
        [Parameter(Mandatory=$true)]
        [string]$NewGroup
    )

    # Validar que el grupo sea válido ("reprobados" o "recursadores")
    if ($NewGroup -ne "reprobados" -and $NewGroup -ne "recursadores") {
        Write-Host "Error: El grupo no es válido. Solo se permiten los grupos 'reprobados' o 'recursadores'."
        return
    }
    
    # Obtener el grupo actual del usuario
    $userGroups = Get-LocalGroupMember -Group "recursadores" -Member $Username -ErrorAction SilentlyContinue
    $otherGroup = Get-LocalGroupMember -Group "reprobados" -Member $Username -ErrorAction SilentlyContinue
    
    $currentGroup = $null
    if ($userGroups) {
        $currentGroup = "recursadores"
    } elseif ($otherGroup) {
        $currentGroup = "reprobados"
    }
    
    # Validar si el grupo actual es el mismo que el nuevo grupo
    if ($currentGroup -eq $NewGroup) {
        Write-Host "El usuario '$Username' ya pertenece al grupo '$NewGroup'. No se requieren cambios."
        return
    }
    
    # Si el usuario pertenece a alguno de los grupos, removerlo
    if ($currentGroup) {
        try {
            Remove-LocalGroupMember -Group $currentGroup -Member $Username
            if (Test-Path "C:\FTPRoot\LocalUser\$Username\$currentGroup") {
                Remove-Item "C:\FTPRoot\LocalUser\$Username\$currentGroup" -Recurse -Force
            }
            Write-Host "Usuario '$Username' removido del grupo '$currentGroup'."
        } catch {
            Write-Host "Error al remover el usuario del grupo actual: $_"
            return
        }
    }
    
    # Agregar el usuario al nuevo grupo
    try {
        Add-LocalGroupMember -Group $NewGroup -Member $Username
        
        # Crear la unión de directorio
        New-Item -ItemType Junction -Path "C:\FTPRoot\LocalUser\$Username\$NewGroup" -Target "C:\FTPRoot\$NewGroup"
        
        # Establecer permisos
        icacls "C:\FTPRoot\LocalUser\$Username\$NewGroup" /grant "$($Username):(OI)(CI)F"
        icacls "C:\FTPRoot\$NewGroup" /grant "$($Username):(OI)(CI)F"
        
        # Reiniciar el sitio
        Restart-Site
        
        Write-Host "Usuario '$Username' agregado exitosamente al grupo '$NewGroup'."
    } catch {
        Write-Host "Error al agregar el usuario al nuevo grupo: $_"
        return
    }
}

function delete_user([String]$Username) {
    $UserDelete = $Username
    if(!(Get-LocalUser -Name $UserDelete -ErrorAction SilentlyContinue)){
        echo "El usuario no existe"
    }
    elseif($UserDelete.length -gt 20){
        echo "El nombre de usuario excede el valor maximo de caracteres permitidos"
    }
    elseif([String]::IsNullOrEmpty($UserDelete)){
        echo "El campo de usuario no debe quedar vacio ni contener valores nulos"
    }
    else{
        rm -Force "C:\FTPRoot\LocalUser\$UserDelete" -Recurse
        rm "C:\FTPRoot\Users\$UserDelete" -Recurse -Force
        Remove-LocalUser -Name $UserDelete
        echo "Usuario eliminado"
    }
}

function configurar_permisos ([String]$FTPUserGroupName) {
    $FTPSitePath = "IIS:\Sites\Default FTP Site"
    $BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'
    
    # Habilitar autenticación básica en IIS
    Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $True
    
    # Configurar el aislamiento de usuario (CRUCIAL)
    Set-ItemProperty -Path $FTPSitePath -Name "ftpServer.userIsolation.mode" -Value "IsolateUsingUserName"
    
    # Asegurarse de que la ruta física apunte al directorio base correcto
    Set-ItemProperty -Path $FTPSitePath -Name "physicalPath" -Value "C:\FTPRoot\LocalUser"
    
    # Configurar permisos en IIS para el grupo de usuarios FTP
    $Param = @{
        Filter = "/system.ftpServer/security/authorization"
        Value = @{
            accessType = "Allow"
            roles = "$FTPUserGroupName"
            permissions = 3
        }
        PSPath = 'IIS:\'
        Location = "Default FTP Site"
    }
    Add-WebConfiguration @Param
    
    # Reiniciar el servicio FTP para aplicar los cambios
    Restart-Service ftpsvc -Force -ErrorAction SilentlyContinue
    
    Write-Output "Permisos de IIS configurados para '$FTPUserGroupName' en 'Default FTP Site'."
}


function Validate-Password {
    param ([string]$Password)
    
    if ($Password.Length -lt 8) {
        Write-Output "Error: La contraseña debe tener al menos 8 caracteres."
        return $false
    }
    if ($Password -notmatch "[A-Z]") {
        Write-Output "Error: La contraseña debe contener al menos una letra mayúscula."
        return $false
    }
    if ($Password -notmatch "[a-z]") {
        Write-Output "Error: La contraseña debe contener al menos una letra minúscula."
        return $false
    }
    if ($Password -notmatch "[0-9]") {
        Write-Output "Error: La contraseña debe contener al menos un número."
        return $false
    }
    if ($Password -notmatch "[!@#$%^&*()_+=]") {
        Write-Output "Error: La contraseña debe contener al menos un carácter especial (!@#$%^&*()_+=)."
        return $false
    }
    
    return $true
}