#!/bin/bash

# Función para limpiar configuraciones existentes
cleanup_existing_config() {
    echo "Limpiando configuraciones existentes..."
    # Detener el servicio vsftpd
    sudo systemctl stop vsftpd
    # Desmontar puntos de montaje existentes relacionados con /srv/ftp
    for mount_point in $(mount | grep "/srv/ftp" | awk '{print $3}'); do
        echo "Desmontando $mount_point"
        sudo umount "$mount_point" 2>/dev/null
    done
    # Hacer backup del fstab
    sudo cp /etc/fstab /etc/fstab.backup
    # Limpiar entradas de /srv/ftp del fstab
    sudo grep -v "/srv/ftp/" /etc/fstab.backup | sudo tee /etc/fstab > /dev/null
    echo "Limpieza completada."
}

# Función para agregar entrada de montaje si no existe
add_mount_entry() {
    local source="$1"
    local target="$2"
    if ! grep -q "$source $target" /etc/fstab; then
        echo "$source $target none bind 0 0" | sudo tee -a /etc/fstab
    else
        echo "La entrada de montaje para $target ya existe en /etc/fstab, omitiendo..."
    fi
}

# Función para montar directorios de forma segura
mount_directory() {
    local source="$1"
    local target="$2"
    # Verificar que los directorios existen
    if [[ ! -d "$source" ]] || [[ ! -d "$target" ]]; then
        echo "Error: Directorio fuente o destino no existe"
        return 1
    fi
    # Desmontar si ya está montado
    if mountpoint -q "$target" 2>/dev/null; then
        sudo umount "$target"
    fi
    # Realizar el montaje
    sudo mount --bind "$source" "$target"
    # Agregar al fstab solo si no existe
    add_mount_entry "$source" "$target"
}

# Función para validar nombres de usuario
userValid() {
    local usuario="$1"
    # Verificar si está vacío
    if [[ -z "$usuario" ]]; then
        echo "El nombre de usuario no puede estar vacío"
        return 1
    fi
    # Verificar el formato del nombre de usuario
    if [[ ! "$usuario" =~ ^[a-zA-Z]*$ ]]; then
        return 1
    fi
    return 0
}

# Función para validar contraseñas
passwordValid() {
    local password="$1"
    
    # Verificar longitud mínima (6 caracteres)
    if [[ ${#password} -lt 6 ]]; then
        echo "La contraseña debe tener al menos 6 caracteres"
        return 1
    fi
    
    # Verificar que contenga al menos un número
    if ! [[ "$password" =~ [0-9] ]]; then
        echo "La contraseña debe contener al menos un número"
        return 1
    fi
    
    # Verificar que contenga al menos un carácter especial
    # Versión corregida para evitar problemas de escape
    if ! [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        echo "La contraseña debe contener al menos un carácter especial"
        return 1
    fi
    
    return 0
}

# Función para crear usuarios
createUser() {
    local usuario="$1"
    local grupo="$2"
    if [[ -d "/srv/ftp/usuarios/$usuario" ]]; then
        echo "El usuario '$usuario' ya existe"
        return 1
    fi
    # Crear directorios
    sudo mkdir -p "/srv/ftp/usuarios/$usuario"
    sudo mkdir -p "/srv/ftp/usuarios/$usuario/publico"
    sudo mkdir -p "/srv/ftp/usuarios/$usuario/$grupo"
    sudo mkdir -p "/srv/ftp/usuarios/$usuario/$usuario"
    # Crear usuario y configurar permisos
    sudo useradd -m -d "/srv/ftp/usuarios/$usuario/$usuario" -s /bin/bash -G "$grupo" "$usuario"
    
    # Solicitar y validar contraseña
    local password=""
    local password_confirm=""
    while true; do
        read -s -p "Ingrese contraseña para '$usuario' (mínimo 6 caracteres, al menos un número y un carácter especial): " password
        echo
        if ! passwordValid "$password"; then
            continue
        fi
        
        read -s -p "Confirme la contraseña: " password_confirm
        echo
        
        if [[ "$password" != "$password_confirm" ]]; then
            echo "Las contraseñas no coinciden. Intente nuevamente."
            continue
        fi
        
        break
    done
    
    # Establecer la contraseña
    echo "$usuario:$password" | sudo chpasswd
    
    sudo usermod -aG "$grupo" "$usuario"
    sudo chown "$usuario:$grupo" "/srv/ftp/usuarios/$usuario/$usuario"
    sudo chmod 700 "/srv/ftp/usuarios/$usuario/$usuario"
    # Montar directorios de forma segura
    mount_directory "/srv/ftp/$grupo" "/srv/ftp/usuarios/$usuario/$grupo"
    mount_directory "/srv/ftp/publico" "/srv/ftp/usuarios/$usuario/publico"
    echo "Usuario '$usuario' creado exitosamente en el grupo '$grupo'"
}

# Función para eliminar usuario
deleteUser() {
    local usuario="$1"
    # Verificar si el usuario existe
    if ! id "$usuario" >/dev/null 2>&1; then
        echo "El usuario '$usuario' no existe"
        return 1
    fi
    # Desmontar directorios del usuario
    for mount_point in $(mount | grep "/srv/ftp/usuarios/$usuario" | awk '{print $3}'); do
        sudo umount "$mount_point" 2>/dev/null
    done
    # Eliminar usuario y sus directorios
    sudo userdel -r "$usuario"
    sudo rm -rf "/srv/ftp/usuarios/$usuario"
    echo "Usuario '$usuario' eliminado exitosamente"
}

# Función para cambiar grupo de usuario
changeUserGroup() {
    local usuario="$1"
    local nuevoGrupo="$2"
    # Verificar si el usuario existe
    if ! id "$usuario" >/dev/null 2>&1; then
        echo "El usuario '$usuario' no existe"
        return 1
    fi
    # Obtener grupo actual
    local grupoActual=$(groups "$usuario" | grep -o -E "reprobados|recursadores" | head -1)
    if [[ "$grupoActual" == "$nuevoGrupo" ]]; then
        echo "El usuario ya pertenece al grupo $nuevoGrupo"
        return 1
    fi
    # Remover del grupo actual si existe
    if [[ -n "$grupoActual" ]]; then
        echo "Removiendo del grupo actual: $grupoActual"
        sudo gpasswd -d "$usuario" "$grupoActual"
    fi
    # Agregar al nuevo grupo
    echo "Agregando al nuevo grupo: $nuevoGrupo"
    sudo usermod -aG "$nuevoGrupo" "$usuario"
    # Actualizar directorios y montajes
    if [[ -d "/srv/ftp/usuarios/$usuario" ]]; then
        # Desmontar el directorio del grupo anterior
        if [[ -n "$grupoActual" ]]; then
            echo "Desmontando directorio del grupo anterior"
            sudo umount "/srv/ftp/usuarios/$usuario/$grupoActual" 2>/dev/null
            sudo rm -rf "/srv/ftp/usuarios/$usuario/$grupoActual"
        fi
        echo "Creando y montando nuevo directorio de grupo"
        # Crear y montar el directorio del nuevo grupo
        sudo mkdir -p "/srv/ftp/usuarios/$usuario/$nuevoGrupo"
        mount_directory "/srv/ftp/$nuevoGrupo" "/srv/ftp/usuarios/$usuario/$nuevoGrupo"
        # Actualizar permisos
        sudo chown "$usuario:$nuevoGrupo" "/srv/ftp/usuarios/$usuario/$nuevoGrupo"
        sudo chmod 750 "/srv/ftp/usuarios/$usuario/$nuevoGrupo"
    fi
    # Verificar el cambio
    if groups "$usuario" | grep -q "$nuevoGrupo"; then
        echo "Usuario '$usuario' movido exitosamente al grupo '$nuevoGrupo'"
        return 0
    else
        echo "Error: No se pudo cambiar el grupo del usuario"
        return 1
    fi
}

# Función para mostrar el menú
show_menu() {
    clear
    echo "1. Agregar usuario"
    echo "2. Cambiar grupo de usuario"
    echo "3. Eliminar usuario"
    echo "4. Salir"
    echo "Seleccione una opción:"
}

# Función principal del menú
menu_principal() {
    while true; do
        show_menu
        read -r opcion
        case $opcion in
            1) # Agregar usuario
                while true; do
                    read -p "Ingrese el nombre del usuario: " nombreUsuario
                    if userValid "$nombreUsuario"; then
                        break
                    fi
                    echo "Por favor, ingrese un nombre de usuario válido."
                done
                
                while true; do
                    read -p "Ingrese el grupo (reprobados/recursadores): " nombreGrupo
                    if [[ "$nombreGrupo" == "reprobados" || "$nombreGrupo" == "recursadores" ]]; then
                        break
                    fi
                    echo "Grupo inválido. Use 'reprobados' o 'recursadores'"
                done
                
                createUser "$nombreUsuario" "$nombreGrupo"
                ;;
            2) # Cambiar grupo
                clear
                read -p "Ingrese el nombre del usuario: " nombreUsuario
                # Verificar si el usuario existe
                if ! id "$nombreUsuario" >/dev/null 2>&1; then
                    echo "Error: El usuario $nombreUsuario no existe"
                    continue
                fi
                # Mostrar grupo actual
                grupoActual=$(groups "$nombreUsuario" | grep -o -E "reprobados|recursadores" | head -1)
                echo "Grupo actual: $grupoActual"
                
                while true; do
                    read -p "Ingrese el nuevo grupo (reprobados/recursadores): " nuevoGrupo
                    if [[ "$nuevoGrupo" == "reprobados" || "$nuevoGrupo" == "recursadores" ]]; then
                        if [[ "$grupoActual" == "$nuevoGrupo" ]]; then
                            echo "El usuario ya pertenece a ese grupo"
                        else
                            if changeUserGroup "$nombreUsuario" "$nuevoGrupo"; then
                                echo "Cambio de grupo realizado "
                            else
                                echo "Error al cambiar de grupo"
                            fi
                        fi
                        break
                    else
                        echo "Grupo inválido. Use 'reprobados' o 'recursadores'"
                    fi
                done
                ;;
            3) # Eliminar usuario
                read -p "Ingrese el nombre del usuario a eliminar: " nombreUsuario
                read -p "¿Está seguro de eliminar al usuario '$nombreUsuario'? (s/n): " confirmar
                if [[ "$confirmar" == "s" ]]; then
                    deleteUser "$nombreUsuario"
                fi
                ;;
            4) # Salir
                echo "Saliendo"
                exit 0
                ;;
            *)
                echo "Opción inválida"
                ;;
        esac
    done
}

main() {
    # Instalar vsftpd
    sudo apt install vsftpd -y
    
    # Limpiar configuraciones existentes
    cleanup_existing_config
    
    # Crear grupos
    sudo groupadd reprobados 2>/dev/null || echo "El grupo reprobados ya existe"
    sudo groupadd recursadores 2>/dev/null || echo "El grupo recursadores ya existe"
    
    # Crear estructura de directorios
    sudo mkdir -p /srv/ftp/
    sudo mkdir -p /srv/ftp/publico
    sudo mkdir -p /srv/ftp/reprobados
    sudo mkdir -p /srv/ftp/recursadores
    sudo mkdir -p /srv/ftp/usuarios
    sudo mkdir -p /srv/ftp/public/
    sudo mkdir -p /srv/ftp/public/publico
    
    # Montar directorio público de forma segura
    mount_directory "/srv/ftp/public/publico" "/srv/ftp/publico"
    
    # Configurar permisos
    sudo chmod 777 /srv/ftp/publico
    sudo chmod 755 /srv/ftp/usuarios
    sudo chown :reprobados /srv/ftp/reprobados
    sudo chmod 770 /srv/ftp/reprobados
    sudo chown :recursadores /srv/ftp/recursadores
    sudo chmod 770 /srv/ftp/recursadores
    
    # Configuración mejorada de vsftpd
    cat <<EOF | sudo tee /etc/vsftpd.conf
# Configuración básica
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
anon_root=/srv/ftp/public

# Configuración de chroot
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=\$USER
local_root=/srv/ftp/usuarios/\$USER

# Configuración de modo pasivo
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30100

# Registro
xferlog_std_format=YES
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES

# Seguridad
pam_service_name=vsftpd
seccomp_sandbox=NO
EOF
    
    # Configurar firewall
    sudo ufw allow 20,21/tcp
    sudo ufw allow 30000:31000/tcp
    sudo ufw enable
    
    # Recargar systemd y reiniciar vsftpd
    sudo systemctl daemon-reload
    sudo systemctl restart vsftpd
    sudo systemctl enable vsftpd
    
    # Verificar el estado del servicio
    echo "Verificando el estado del servicio vsftpd..."
    sudo systemctl status vsftpd
    echo "Configuración completada. Si hay problemas, revise los logs con: sudo journalctl -u vsftpd.service -n 50 --no-pager"
}

# Ejecutar la función principal
main

# Iniciar el menú principal
menu_principal