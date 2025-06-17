#!/bin/bash

# Función para validar el nombre de usuario
validate_username() {
    while true; do
        read -p "Ingrese el nombre de usuario (3-20 caracteres, solo letras, números o '_'), o 'salir' para terminar: " USERNAME
        if [[ "$USERNAME" == "salir" ]]; then
            echo "Saliendo..."
            exit 0
        # Validar que solo contiene letras, números y _ y que tenga al menos una letra
        elif [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]{3,20}$ ]] || [[ ! "$USERNAME" =~ [a-zA-Z] ]]; then
            echo "Nombre de usuario inválido. Solo se permiten letras, números o '_', y debe contener al menos una letra."
        else
            break
        fi
    done
}

# Función para validar la contraseña
validate_password() {
    while true; do
        read -s -p "Ingrese la contraseña (mínimo 8 caracteres, debe incluir una letra, un número y un símbolo especial): " PASSWORD
        echo
        read -s -p "Confirme la contraseña: " CONFIRM_PASSWORD
        echo
        if [[ "$PASSWORD" != "$CONFIRM_PASSWORD" ]]; then
            echo "Las contraseñas no coinciden. Intente nuevamente."
        elif [[ ! "$PASSWORD" =~ [a-zA-Z] || ! "$PASSWORD" =~ [0-9] || ! "$PASSWORD" =~ [@#%^*] || ${#PASSWORD} -lt 8 ]]; then
            echo "La contraseña debe tener al menos 8 caracteres, incluir una letra, un número y un símbolo especial (@#%^*)."
        else
            break
        fi
    done
}

# Función para seleccionar el grupo
select_group() {
    while true; do
        echo "Seleccione el grupo para crear la carpeta:"
        echo "1) Reprobados"
        echo "2) Recursadores"
        read -p "Opción (1/2), o 'salir' para terminar: " GROUP_OPTION
        if [[ "$GROUP_OPTION" == "salir" ]]; then
            echo "Saliendo..."
            exit 0
        elif [[ "$GROUP_OPTION" == "1" ]]; then
            GROUP="Reprobados"
            break
        elif [[ "$GROUP_OPTION" == "2" ]]; then
            GROUP="Recursadores"
            break
        else
            echo "Opción no válida. Intente nuevamente."
        fi
    done
}

# Función para verificar si el usuario ya existe
check_user_exists() {
    if id "$USERNAME" &>/dev/null; then
        echo "Error: El usuario '$USERNAME' ya existe. Ingrese otro nombre de usuario."
        return 1  # Regresa 1 para indicar que el usuario existe
    fi
    return 0  # Regresa 0 si el usuario no existe
}

# Función para agregar el usuario
add_user() {
    while true; do
        validate_username
        check_user_exists   # Llamada a la función para verificar si el usuario existe
        if [ $? -eq 0 ]; then  # Si el usuario no existe, se continúa
            break
        fi
    done

    validate_password
    select_group

    # Configuración del servidor FTP
    apt update && apt install -y vsftpd
    systemctl enable vsftpd

    # Crear directorios principales
    mkdir -p /srv/ftp/General /srv/ftp/Reprobados /srv/ftp/Recursadores
    chmod 755 /srv/ftp/General
    chmod 770 /srv/ftp/Reprobados
    chmod 770 /srv/ftp/Recursadores

    groupadd Reprobados
    groupadd Recursadores

    chown root:Reprobados /srv/ftp/Reprobados
    chown root:Recursadores /srv/ftp/Recursadores

    # Configurar vsftpd para permitir solo acceso a las carpetas especificadas
    echo "local_enable=YES" >> /etc/vsftpd.conf
    echo "write_enable=YES" >> /etc/vsftpd.conf
    echo "chroot_local_user=YES" >> /etc/vsftpd.conf
    echo "allow_writeable_chroot=YES" >> /etc/vsftpd.conf
    echo "user_sub_token=$USER" >> /etc/vsftpd.conf
    echo "local_root=/home/$USERNAME" >> /etc/vsftpd.conf

    systemctl restart vsftpd
    echo "Servidor FTP configurado correctamente."

    # Configurar usuario anónimo (solo lectura en /srv/ftp/General)
    ANON_CONF=$(cat <<EOF

    # Configuración para usuario anónimo
    anonymous_enable=YES
    anon_root=/srv/ftp/General
    anon_upload_enable=NO
    anon_mkdir_write_enable=NO
    anon_other_write_enable=NO
    EOF
    )

    # Evita duplicar configuraciones si ya existen
    if ! grep -q "anonymous_enable=YES" /etc/vsftpd.conf; then
        echo "$ANON_CONF" >> /etc/vsftpd.conf
    fi

    chmod 755 /srv/ftp/General  # Permitir lectura para todos
    chown ftp:ftp /srv/ftp/General  # Establecer como propiedad del usuario ftp


    # Crear el usuario y carpetas
    useradd -m -s /bin/bash -p "$(openssl passwd -1 "$PASSWORD")" -G "$GROUP" "$USERNAME"
    HOME_DIR="/home/$USERNAME"

    # Crear carpeta personal del usuario
    mkdir -p "$HOME_DIR/Personal"

    # Crear carpeta del grupo seleccionado
    mkdir -p "$HOME_DIR/$GROUP"
    mount --bind "/srv/ftp/$GROUP" "$HOME_DIR/$GROUP"

    if ! grep -q "$HOME_DIR/$GROUP" /etc/fstab; then
        echo "/srv/ftp/$GROUP $HOME_DIR/$GROUP none bind 0 0" >> /etc/fstab
    fi

    # Crear y montar carpeta General
    mkdir -p "$HOME_DIR/General"
    mount --bind "/srv/ftp/General" "$HOME_DIR/General"

    if ! grep -q "$HOME_DIR/General" /etc/fstab; then
        echo "/srv/ftp/General $HOME_DIR/General none bind 0 0" >> /etc/fstab
    fi

    # Permitir que el usuario vea las carpetas Personal, General y la del grupo en FTP
    chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
    chmod 700 "$HOME_DIR"
    chmod 755 "$HOME_DIR/General"
    chmod 750 "$HOME_DIR/$GROUP"
    chmod 700 "$HOME_DIR/Personal"

    echo "Usuario $USERNAME creado con acceso a su carpeta Personal, General y $GROUP."
}

# Menú principal para continuar agregando usuarios
while true; do
    echo "¿Qué desea hacer?"
    echo "1) Agregar un usuario"
    echo "2) Salir"
    read -p "Opción: " OPTION

    case $OPTION in
        1) add_user ;;
        2) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
done