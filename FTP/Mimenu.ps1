# Importar funciones
. C:\Users\Administrador\Documents\Funciones_FTP.ps1

# Inicializar carpetas y montar unidades
Configure-FTPServer
create_groups
Enabled-Autentication
Enabled-SSL
Enabled-AccessAnonym
Restart-Site
# create_files_FTP

# Menú interactivo
while ($true) {
    Write-Host "`n===== GESTIÓN DE USUARIOS FTP ====="
    Write-Host "1) Crear un usuario FTP"
    Write-Host "2) Cambiar usuario de grupo"
    Write-Host "3) Eliminar usuario"
    Write-Host "0) Salir"
    $option = Read-Host "Seleccione una opción"

    switch ($option) {
        "1" {
            $user = Read-Host "Ingrese el nombre de usuario"
            # Validar que no esté en blanco
            if((Get-LocalUser -Name $user -ErrorAction SilentlyContinue)){
                Write-Host "El usuario ya existe"
            }
            elseif ([string]::IsNullOrWhiteSpace($user)) {
                Write-Host "Error: El nombre de usuario no puede estar en blanco." -ForegroundColor Red
            }
            elseif ($user.length -gt 20){
                Write-Host "El nombre de usuario excede el maximo de caracteres permitido para un usuario"
            }
            elseif ($user -match "^[^a-zA-Z0-9]") {
                Write-Host "El nombre de usuario no puede comenzar con un carácter especial. Intente de nuevo." -ForegroundColor Red
            }
            else{
                # Bucle para validar la contraseña
                $passwordValid = $false
                do {
                    $passwd = Read-Host "Ingrese la contraseña"
                    $passwordValid = Validate-Password -Password $passwd
        
                    if (-not $passwordValid) {
                        Write-Host "Por favor, intente con otra contraseña." -ForegroundColor Yellow
                    }
                } while (-not $passwordValid)
    
                # Bucle para validar el grupo
                do {
                    $group = Read-Host "Asignele un grupo al usuario creado (reprobados/recursadores)"
        
                    if ($group -eq "reprobados" -or $group -eq "recursadores") {
                        create_user -Username $user -Password $passwd -Group $group
                        add_user_to_group -Username $user -GroupName $group
                        Restart-Site
                        break 2 # Salir de ambos bucles si el grupo es válido
                    } else {
                        Write-Host "Grupo no válido. Debe ser 'reprobados' o 'recursadores'." -ForegroundColor Red
                    }
                } while ($true)
            }
        }
        "2" {
            # Solicitar y validar el nombre de usuario
            $user = Read-Host "Ingrese el nombre de usuario"
    
            # Validar que no esté en blanco
            if ([string]::IsNullOrWhiteSpace($user)) {
                Write-Host "Error: El nombre de usuario no puede estar en blanco." -ForegroundColor Red
                break # Salir del bucle principal si está en blanco
            }
    
            # Validar que no supere 20 caracteres
            if ($user.Length > 20) {
                Write-Host "Error: El nombre de usuario no puede superar los 20 caracteres." -ForegroundColor Red
                break # Salir del bucle principal si supera 20 caracteres
            }
            elseif ($user -match "^[^a-zA-Z0-9]") {
                Write-Host "El nombre de usuario no puede comenzar con un carácter especial. Intente de nuevo." -ForegroundColor Red
            }
    
            # Validar que el usuario exista
            try {
                $userExists = Get-LocalUser -Name $user -ErrorAction Stop
            }
            catch {
                Write-Host "Error: El usuario '$user' no existe en el sistema." -ForegroundColor Red
                break # Salir del bucle principal si el usuario no existe
            }
            $group = Read-Host "Ingrese el nombre del grupo al que se va a cambiar"
            Change-UserGroup -Username $user -NewGroup $group
        }
        "3" { 
            $user = Read-Host "Ingresa el usuario a eliminar"
            if((Get-LocalUser -Name $user -ErrorAction SilentlyContinue)){
                Write-Host "El usuario ya existe"
            }
            elseif ([string]::IsNullOrWhiteSpace($user)) {
                Write-Host "Error: El nombre de usuario no puede estar en blanco." -ForegroundColor Red
            }
            elseif ($user.length -gt 20){
                Write-Host "El nombre de usuario excede el maximo de caracteres permitido para un usuario"
            }
            elseif ($user -match "^[^a-zA-Z0-9]") {
                Write-Host "El nombre de usuario no puede comenzar con un carácter especial. Intente de nuevo." -ForegroundColor Red
            }
            else {
                delete_user -Username $user
                Restart-Site
            }
        }
        "0" {
            break
        }
        default { Write-Host "Opción inválida" }
    }
}