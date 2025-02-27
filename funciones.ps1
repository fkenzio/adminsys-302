# Función que valida si una cadena es una dirección IP válida
function Validar-IP {
    param(
        [string]$ip
    )
    # Expresión regular para validar una dirección IPv4
    if ($ip -match '^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$') {
        return $true
    }
    else {
        return $false
    }
}

# Función que solicita al usuario ingresar un dominio e IP, y valida la IP
function Solicitar-Datos {
    # Solicitar el dominio
    $DOMINIO = Read-Host "Por favor, ingresa el dominio"

    # Bucle para asegurarse de que la IP ingresada es válida
    do {
        $IP = Read-Host "ingresa la dirección IP: "
        if (-not (Validar-IP -ip $IP)) {
            Write-Host "la dirección IP ingresada no es válida. Intenta nuevamente"
        }
    } while (-not (Validar-IP -ip $IP))  # Se repite hasta que la IP sea válida

    # Retornar los valores en un objeto
    return @{ Dominio = $DOMINIO; IP = $IP }
}

function Configurar_DHCP {
    Add-DHCPServerV4Scope
    Set-DHCPServerV4OptionValue -ScopeId 192.168.0.0 -DnsServer 8.8.8.8 -Router 192.168.0.1
    Restart-Service dhcpserver
}

Export-ModuleMember -Function Validar-IP, Solicitar-Datos, Configurar_DHCP