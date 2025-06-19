# Script que ayuda a incluir openSSL en el PATH para crear certificados autofirmados SSL
# Este script fue mi salvador en esta practica

$opensslPath = "C:\Program Files\OpenSSL-Win64\bin"

# Agregar al PATH del sistema
[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine) + ";$opensslPath",
    [EnvironmentVariableTarget]::Machine
)

# Actualizar el PATH en la sesión actual
$env:Path += ";$opensslPath"

openssl version

# Crear el certificado autofirmado
openssl req -x509 -newkey rsa:4096 -keyout private.key -out certificate.crt -days 365 -nodes