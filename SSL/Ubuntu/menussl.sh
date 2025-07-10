#!/bin/bash
###############################################################################
# MENÚ PRINCIPAL que invoca:
#  1) sslUbuntu.sh -> Función principal supuesta: Mostrar_Menu_Instalacion
#  2) ubuntuconFTP.SH -> Función principal supuesta: shown_main_menu
###############################################################################

#!/bin/bash
###############################################################################
# MENÚ PRINCIPAL que invoca:
#  1) sslUbuntu.sh -> Función principal: Mostrar_Menu_Instalacion (instalación vía web)
#  2) ubuntuconFTP.sh -> Función principal: shown_main_menu (instalación vía FTP/FTPS)
###############################################################################

while true; do
    clear
    echo "=========================================="
    echo "       MENÚ PRINCIPAL - Mis Scripts"
    echo "=========================================="
    echo "1) Ejecutar sslUbuntu.sh (Instalación vía web/SSL)"
    echo "2) Ejecutar ubuntuconFTP.sh (Instalación vía FTP/FTPS)"
    echo "3) Salir"
    echo "=========================================="
    read -p "Seleccione una opción (1-3): " opcion

    case "$opcion" in
        1)
            echo "Cargando (source) sslUbuntu.sh..."
            source sslUbunutu.sh
            if declare -f Mostrar_Menu_Instalacion > /dev/null; then
                Mostrar_Menu_Instalacion
            else
                echo "Error: La función 'Mostrar_Menu_Instalacion' no se encontró en sslUbuntu.sh."
            fi
            ;;
        2)
            echo "Cargando (source) ubuntuconFTP.sh..."
            source ubuntuconFTP.sh
            if declare -f shown_main_menu > /dev/null; then
                shown_main_menu
            else
                echo "Error: La función 'shown_main_menu' no se encontró en ubuntuconFTP.sh."
            fi
            ;;
        3)
            echo "Saliendo del menú principal."
            exit 0
            ;;
        *)
            echo "Opción inválida. Por favor, seleccione 1, 2 o 3."
            ;;
    esac

    read -p "Presione Enter para volver al menú..."
done
