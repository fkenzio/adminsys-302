function instalarFTP(){

echo "Instalando FTP........."

Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature -Verbose

echo "Instalando herramientas web-server......."

Install-WindowsFeature Web-Server -IncludeManagementTools

echo "Ftp instalado"

crearcarpetas

}

function importarmodule(){

echo "importando modulo web-administration"
Import-Module WebAdministration

echo "Modulo importado"
}

function crearsitioFTP(){

Param([String]$FTPSiteName,[String]$FTPRootDIR,[String]$FTPPort)

echo "creando sitio web..."

New-WebFTPSite -Name $FTPSiteName -Port $FTPPort -PhysicalPath $FTPRootDIR

echo "sitio web creado"
}


function creargrupoFTP(){

Param ([String]$GroupName, [String]$FTPSiteName)

$ADSI = [ADSI] "WinNT://$env:ComputerName"

$FTPUserGroup = $ADSI.Create("Group", "$GroupName")
$FTPUserGroup.SetInfo()
$FTPUserGroup.Description = "Los de este grupo les dice conectense"
$FTPUserGroup.SetInfo()

mkdir C:\FTP\$GroupName

AutenticacionFtpGroups $FTPSiteName $GroupName


}

function crearusuarioFTP(){

Param ([String]$NombreUser,[String]$Password)

$ADSI = [ADSI] "WinNT://$env:ComputerName"

$CreateUserFTPUser = $ADSI.Create("User", "$NombreUser")
$CreateUserFTPUser.SetInfo()
$CreateUserFTPUser.SetPassword("$Password")
$CreateUserFTPUser.SetInfo()


mkdir C:\FTP\LocalUser\$NombreUser
mkdir C:\FTP\LocalUser\$NombreUser\$NombreUser


cmd /c mklink /D C:\FTP\LocalUser\$NombreUser\Publica C:\FTP\Publica

}


function asignarusuariogrupo(){

Param ([String]$NombreUser,[String]$GroupName,[String]$FTPSiteName)

$UserAccount = New-Object System.Security.Principal.NTAccount("$NombreUser")
$SID = $UserAccount.Translate([System.Security.Principal.SecurityIdentifier])
$Group = [ADSI]"WinNT://$env:ComputerName/$GroupName,Group"
$User = [ADSI]"WinNT://$SID"
$Group.Add($User.Path)


cmd /c mklink /D C:\FTP\LocalUser\$NombreUser\$GroupName C:\FTP\$GroupName

$FTPRootDir ="C:\FTP\LocalUser\$NombreUser\$GroupName"

SetNtfsPermissions $GroupName $FTPRootDir $FTPSiteName

}

function crearcarpetas(){

mkdir C:\FTP
mkdir C:\FTP\Publica
mkdir C:\FTP\LocalUser


}


function AutenticacionFtp(){

Param ([String]$FTPSiteName)

$FTPSitePath = "IIS:\\Sites\\$FTPSiteName"
$BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'

Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $True

# Add an Authorization read rule for FTP Users.
$Param = @{
    Filter = "system.ftpServer/security/authorization"
    Value = @{
        accessType = "Allow"
        users = "*"
        permissions = 1
    }
    PSPath = 'IIS:\\'
 Location = "C:\FTP\Publica"
}


Add-WebConfiguration @Param

CambiarSSLpolicies $FTPSitePath

}



function AutenticacionFtpGroups(){

Param ([String]$FTPSiteName, $GroupName)

$FTPSitePath = "IIS:\\Sites\\$FTPSiteName"
$BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'

Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $True

# Add an Authorization read rule for FTP Users.
$Param = @{
    Filter = "system.ftpServer/security/authorization"
    Value = @{
        accessType = "Allow"
        roles = "$GroupName"
        permissions = 3
    }
    PSPath = 'IIS:\\'
 Location = "C:\FTP\Publica"
}


Add-WebConfiguration @Param

AutenticacionFtpGroupsFolders $FTPSiteName $GroupName


}



function AutenticacionFtpGroupsFolders(){

Param ([String]$FTPSiteName, $GroupName)

$FTPSitePath = "IIS:\\Sites\\$FTPSiteName"
$BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'

Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $True

# Add an Authorization read rule for FTP Users.
$Param = @{
    Filter = "system.ftpServer/security/authorization"
    Value = @{
        accessType = "Allow"
        roles = "$GroupName"
        permissions = 3
    }
    PSPath = 'IIS:\\'
 Location = "C:\FTP\$GroupName"
}


Add-WebConfiguration @Param

}










function AutenticacionGroup(){

Param ([String]$FTPSiteName)

$FTPSitePath = "IIS:\\Sites\\$FTPSiteName"
$BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'

Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $True

# Add an Authorization read rule for FTP Users.
$Param = @{
    Filter = "system.ftpServer/security/authorization"
    Value = @{
        accessType = "Allow"
        users = "*"
        permissions = 1
    }
    PSPath = 'IIS:\\'
 Location = "FTP\Publica"
}


Add-WebConfiguration @Param

CambiarSSLpolicies $FTPSitePath

}






function AislarUsuario(){

Param ([String]$FTPSiteName)

Set-ItemProperty -Path "IIS:\Sites\$FTPSiteName" -Name ftpServer.userisolation.mode -Value 3


}


function CambiarSSLpolicies(){

Param ([String]$FTPSitePath)

$SSLPolicy = @(
    'ftpServer.security.ssl.controlChannelPolicy',
    'ftpServer.security.ssl.dataChannelPolicy'
)

Set-ItemProperty -Path $FTPSitePath -Name $SSLPolicy[0] -Value $false
Set-ItemProperty -Path $FTPSitePath -Name $SSLPolicy[1] -Value $false


}

function SetNtfsPermissions(){

Param ([String]$Objeto,[String]$FtpDir,[String]$FtpSiteName)


$UserAccount = New-Object System.Security.Principal.NTAccount($Objeto)
$AccessRule = [System.Security.AccessControl.FileSystemAccessRule]::new($UserAccount, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')

$ACL = Get-Acl -Path $FtpDir
$ACL.SetAccessRule($AccessRule)
$ACL | Set-Acl -Path $FtpDir

# Reiniciar el sitio FTP para que todos los cambios tengan efecto.
Restart-WebItem "IIS:\Sites\$FTPSiteName" -Verbose

}


function ajustarFirewall(){

Set-NetFireWallProfile -Profile Private,Domain,Public -Enabled False
}




function cambiarusergroup(){

Param([String]$NombreUser,[String]$GroupName,[String]$FTPSiteName)
#Obtener grupo actual

$usuario = "$NombreUser"

$salida = net user $usuario

# Filtrar y mostrar los grupos a los que pertenece el usuario
$grupos = $salida | Select-String -Pattern "Miembros del grupo local"
$grupoactual= $grupos -replace "Miembros del grupo local\s*\*",""

$grupoactual= $grupoactual.Trim()

cmd /c rmdir "C:\FTP\LocalUser\$NombreUser\$grupoactual"

Remove-Item -Path "C:\FTP\LocalUser\$NombreUser\$grupoactual" -Recurse -Force

Remove-LocalGroupMember -Group $grupoactual -Member $NombreUser


asignarusuariogrupo $NombreUser $GroupName $FTPSiteName



cmd /c mklink /D C:\FTP\LocalUser\$NombreUser\$GroupName C:\FTP\$GroupName


}



function verificarexistenciauser {

Param ([String]$usuario)

if (Get-LocalUser -Name $usuario){

return $true

}
else{
cls

return $false
}


}


function verificarexistenciagrupo {
Param ([String]$grupo)

if (Get-LocalGroup -Name $grupo){

echo "el grupo existe"

}
else{
cls
echo "el grupo no existe"
}



}




function crearusuarioanonimo(){

Set-ItemProperty "IIS:\Sites\SitioFTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true

mkdir "C:\FTP\LocalUser\Public"



cmd /c mklink /D C:\FTP\LocalUser\Public\Publica C:\FTP\Publica
}