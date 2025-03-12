#!/usr/bin/env bash


source ./ftp_functions.sh

clear

instalarftp

crearanonimo


echo "Bienvenido a la configuracion principal de ftp"

ciclo=true
while $ciclo
do

echo "¿que desea hacer"

echo "1-Crear grupo"

echo "2-Crear usuario"

echo "3-asignar usuario-grupo"

echo "4-cambiar grupo"

echo "5- salir"


read -p "elija una opcion " opc

case $opc in
 1)
    read -p "ingrese el nombre del grupo " grupo
    creargrupo "$grupo"
 ;;
 2)
    read -p "ingrese el nombre de usuario " username
    crearuser "$username"
 ;;
 3)
    read -p "escriba el nombre de usuario a asignar a un grupo " user
    read -p "escriba el nombre del grupo a asignar " grupo
    asignargrupo "$user" "$grupo"
 ;;
 4)
    cambiargrupo
 ;;
 5) 

   ciclo=false
 esac

done


user="roberto"
grupo="recursadore454"

existenciauser "$user"
existenciagrupo "$grupo"
