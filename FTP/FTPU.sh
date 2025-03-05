#!/bin/bash

# Archivo principal que llamará las funciones

# Crear directorio de funciones si no existe
mkdir -p funciones

# Importar funciones
source funciones/instalar_vsftpd.sh
source funciones/configurar_vsftpd.sh
source funciones/agregar_usuario.sh
source funciones/reiniciar_vsftpd.sh

# Instalar y configurar el servidor FTP
instalar_vsftpd
configurar_vsftpd

# Agregar usuarios
while true; do
    read -p "¿Deseas agregar un usuario? (s/n): " opcion
    case "$opcion" in
        [Ss])
            agregar_usuario
            ;;
        [Nn])
            break
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
done

# Reiniciar el servicio para aplicar cambios
reiniciar_vsftpd

echo "Configuración completada. El servidor FTP está listo."

echo "Resumen de configuración:"
echo " - Acceso anónimo habilitado."
echo " - Usuarios pueden escribir en su carpeta, la general y la de su grupo."
echo " - Servidor FTP listo para recibir conexiones."