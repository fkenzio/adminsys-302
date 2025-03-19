$FTPSiteName= "SitioFTP"
$FTPRootDIR= "C:\FTP"
$FTPPort=21
$FTPRootDirLogin= "C:\FTP\LocalUser"


. C:\Users\Administrador\Desktop\FTP\Ftp_Functions.ps1

instalarFTP

importarmodule

crearsitioFTP $FTPSiteName $FTPRootDIR $FTPPort

AutenticacionFtp $FTPSiteName

ajustarFirewall

AislarUsuario $FTPSiteName

crearusuarioanonimo


echo "Bienvenido a la configuracion principal de FTP"

$Ciclo= $true

While ($Ciclo){


echo "¿Que desea hacer?"

echo "1-crear grupo"

echo "2-crear usuario"

echo "3- asignar usuario-grupo"

echo "4- cambiar de grupo"

echo "5-salir"

$Opc = Read-Host "ELija una opcion"

switch($Opc){

1{
$regexespecials = "^([a-z0-9]+(\/{1}[a-z0-9]+)*)+(?!([\/]{2}))$"

$GroupName = Read-Host "Ingrese el nombre de su grupo: ejemplo Reprobados"

if ($GroupName -like "* *" -or $GroupName -notmatch "[a-z]" -or $GroupName.Length -gt 15 -or $GroupName -eq "" -or $GroupName -notmatch $regexespecials){


$InvalidGroupName = $true


while ($InvalidGroupName){

echo "Nombre de grupo invalida, asegurate que no contenga espacios, contenga al menos un caracter, ni supere de 15 caracteres"


$GroupName = Read-Host "Ingrese el nombre de su grupo; por ejemplo: Reprobados"

if ($GroupName -like "* *" -or $GroupName -notmatch "[a-zA-Z0-9]" -or $GroupName.Length -gt 15 -or $GroupName -eq "" -or $GroupName -notmatch $regexespecials){

$InvalidGroupName = $true
}
else{
$InvalidGroupName = $false

}

}


}





creargrupoFTP $GroupName $FTPSiteName

}

2{

#validar nombre de usuario

$UserNombre = Read-Host "Ingrese el nombre de su usuario, por ejemplo: danielvaldez"

$regexespecials = "^([a-z0-9]+(\/{1}[a-z0-9]+)*)+(?!([\/]{2}))$"
$Password = Read-Host "Ingrese el password de su user"


if ($UserNombre -like "* *" -or $UserNombre -notmatch "[a-z]" -or $UserNombre.Length -gt 15 -or $UserNombre -eq "" -or $UserNombre -notmatch $regexespecials){


$InvalidUserName = $true


while ($InvalidUserName){

echo "Nombre de usuario invalido, asegurate que no contenga espacios, contenga al menos un caracter, ni supere de 15 caracteres"


$UserNombre = Read-Host "Ingrese el nombre de su usuario, por ejemplo: danielvaldez"

if ($UserNombre -like "* *" -or $UserNombre -notmatch "[a-zA-Z0-9]" -or $UserNombre.Length -gt 15 -or $UserNombre -eq "" -or $UserNombre -notmatch $regexespecials){

$InvalidUserName = $true
}
else{
$InvalidUserName = $false

}

}


}


#validar la contraseña

if ($Password -like "* *" -or $Password -notmatch "[a-z]" -or $Password.Length -gt 15 -or $Password -eq "" -or $Password -notmatch $regexespecials){


$InvalidUserName = $true


while ($InvalidUserName){

echo "Contraseña invalida, asegurate que no contenga espacios, contenga al menos un caracter, ni supere de 15 caracteres"


$Password = Read-Host "Ingrese el nombre de su grupo; por ejemplo: Reprobados"

if ($Password -like "* *" -or $Password -notmatch "[a-zA-Z0-9]" -or $Password.Length -gt 15 -or $Password -eq "" -or $Password -notmatch $regexespecials){

$InvalidUserName = $true
}
else{
$InvalidUserName = $false

}

}


}



crearusuarioFTP $UserNombre $Password

}



3{



$UserNombre= Read-Host "Ingrese el nombre del usuario a asginar"

if (-not (verificarexistenciauser $UserNombre)){

$UserNotExists=$true

while ($UserNotExists){

echo "El usuario no existe"
$UserNombre= Read-Host "Ingrese el nombre del usuario a asginar"


if (-not (verificarexistenciauser $UserNombre)){
$UserNotExists=$true

}
else{

$UserNotExists=$false
}

}


}


$GroupName = Read-Host "Ingrese el nombre del grupo para asignar al user"


if (-not (verificarexistenciagrupo $GroupName)){

$UserNotExists=$true

while ($UserNotExists){

echo "El grupo no existe"
$UserNombre= Read-Host "Ingrese el nombre del grupo para asignar al user"


if (-not (verificarexistenciauser $GroupName)){
$UserNotExists=$true

}
else{

$UserNotExists=$false
}

}


}



asignarusuariogrupo $UserNombre $GroupName $FTPSiteName


SetNtfsPermissions $GroupName $FTPRootDirLogin $FTPSiteName







}
4{

$NombreUser= Read-Host "Ingrese el nombre de usuario a quien desea cambiar de grupo"


if (-not (verificarexistenciauser $NombreUser)){

$UserNotExists=$true

while ($UserNotExists){

echo "El usuario no existe"
$UserNombre= Read-Host "Ingrese el nombre del usuario a asginar"


if (-not (verificarexistenciauser $NombreUser)){
$UserNotExists=$true

}
else{

$UserNotExists=$false
}

}


}




$GroupName= Read-Host "Ingrese el nuevo grupo del usuario"



if (-not (verificarexistenciagrupo $GroupName)){

$UserNotExists=$true

while ($UserNotExists){

echo "El grupo no existe"
$UserNombre= Read-Host "Ingrese el nombre del grupo para asignar al user"


if (-not (verificarexistenciauser $GroupName)){
$UserNotExists=$true

}
else{

$UserNotExists=$false
}

}


}



cambiarusergroup $NombreUser $GroupName $FTPSiteName

}

5{

$Ciclo=$false

}

default{

clear
echo "elija una opcion valida"

}

}
}