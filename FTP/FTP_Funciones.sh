#!/usr/bin/env bash

instalarftp(){
echo "instalando ftp"
sudo apt-get install vsftpd
clear
echo "ftp instalado correctamente"

crearcarpetas

}


crearcarpetas(){
if [ -d "/home/ftp" ]; then

echo "ftp folder existe"

else

sudo mkdir /home/ftp

fi

if [ -d "/home/ftp/grupos" ]; then

echo "ftp grupos existe"

else

sudo mkdir /home/ftp/grupos
fi

if [ -d "/home/ftp/usuarios" ]; then

echo "ftp usuarios existe"

else

sudo mkdir /home/ftp/usuarios
fi

if [ -d "/home/ftp/publica" ]; then

echo "ftp publica existe"

else

sudo mkdir /home/ftp/publica
fi

}



crearanonimo(){

if [ -d "/anonimo" ]; then

echo "carpeta anonimo ya existe"

else

sudo mkdir /anonimo
fi

if [ -d "/anonimo/publica" ]; then

echo "anonimo publica ya existe"

else

sudo mkdir /anonimo/publica
fi



if sudo grep -q "^anonymous_enable=YES" /etc/vsftpd.conf; then
echo "ya esta"
else

sudo sed -i 's/^anonymous_enable=.*/anonymous_enable=YES/g' /etc/vsftpd.conf

sudo service vsftpd restart

fi


if sudo grep -q "^write_enable=.*" /etc/vsftpd.conf; then
echo "ya esta la escritura bien"
else
sudo mount --bind /home/ftp/publica /anonimo/publica

echo "write_enable=YES" | sudo tee -a /etc/vsftpd.conf
echo "anon_root=/anonimo" | sudo tee -a /etc/vsftpd.conf

sudo service vsftpd restart
fi

}

validarnombre_grupo(){
local grupo="$1"
local maximo=20

if [ -n "$grupo" ] && [ ${#grupo} -le $maximo ]; then

return 1

else 

return 0

fi

}


validarnombre_user(){

local user="$1"
local maximo=20

if [ -n "$user" ] && [ ${#user} -le $maximo ]; then

return 1

else 

return 0

fi

}


creargrupo(){
local grupo="$1"

if validarnombre_grupo "$grupo"; then

echo "nombre de grupo invalido "

InvalidGroupName=true

while $InvalidGroupName ; do

 read -p "ingrese de nuevo el nombre del grupo" grupo
 
if validarnombre_grupo "$grupo"; then
echo "nombre de grupo invalido"

InvalidGroupName=true
else 
InvalidGroupName=false

 
fi
done

fi



if existenciagrupo "$grupo"; then
echo "el grupo ya existe "

InvalidGroup=true

while $InvalidGroup ; do

 read -p "ingrese de nuevo el nombre del grupo" grupo
 
if existenciagrupo "$grupo"; then
echo "el grupo ya existe"

InvalidGroup=true
else 
InvalidGroup=false

 
fi

done

fi

sudo groupadd $grupo

echo "grupo creado"

sudo mkdir /home/ftp/grupos/$grupo

sudo chgrp $grupo /home/ftp/grupos/$grupo
}

crearuser(){
local user="$1"


if validarnombre_user "$user"; then

echo "nombre de usuario invalido "

InvalidUserName=true

while $InvalidUserName; do

 read -p "ingrese de nuevo el nombre del usuario" user
 
if validarnombre_user "$user"; then
echo "nombre de usuario invalido"

InvalidUserName=true
else 
InvalidUserName=false

 
fi
done

fi



if existenciauser "$user"; then
echo "el usuario ya existe "

InvalidUserName=true

while $InvalidUserName; do

 read -p "ingrese de nuevo el nombre del usuario" user
 
if existenciauser "$user"; then
echo "el usuario ya existe"

InvalidUserName=true
else 
InvalidUserName=false

 
fi

done

fi




sudo adduser $user
echo "usuario creado exitosamente"
sudo mkdir /home/$user/$user
sudo mkdir /home/ftp/usuarios/$user


sudo chmod 700 /home/$user/$user
sudo chmod 700 /home/ftp/usuarios/$user

sudo chmod 777 /home/ftp/publica

sudo mkdir /home/$user/publica

sudo chown $user /home/ftp/usuarios/$user

sudo chown $user /home/$user/$user

sudo mount --bind /home/ftp/usuarios/$user /home/$user/$user

sudo mount --bind /home/ftp/publica /home/$user/publica

}

asignargrupo(){
local user="$1"
local grupo="$2"

sudo adduser $user $grupo

echo "grupo asignado"

sudo chmod 774 /home/ftp/grupos/$grupo

sudo mkdir /home/$user/$grupo

sudo mount --bind /home/ftp/grupos/$grupo /home/$user/$grupo



}

cambiargrupo(){

read -p "escriba al usuario a quien desea cambiar de grupo " user
read -p "escriba el nuevo grupo de ese usuario " group

grupoactual=$(groups "$user" | awk '{print $5}')

{
sudo umount /home/$user/$grupoactual
} || {

echo "hubo un problema"
exit 1

}

sudo deluser $user $grupoactual
sudo adduser $user $group

sudo mv /home/$user/$grupoactual /home/$user/$group

sudo mount --bind /home/ftp/grupos/$group /home/$user/$group

sudo chgrp $group /home/$user/$group

}

existenciauser(){
local user="$1"

existencia=false

if id $user &> /dev/null; then

    existencia=0
else
  existencia=1

fi

return "$existencia"

}


existenciagrupo(){
local grupo="$1"

existencia=false

if getent group "$grupo" > /dev/null 2 >&1; then

   existencia=0
else

  existencia=1
fi

return "$existencia"

}
