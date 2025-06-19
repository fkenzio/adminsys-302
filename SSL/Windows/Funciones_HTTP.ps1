# Función para obtener el HTML de la página
function Get-HTML {
    param (
        [string]$url
    )
    return Invoke-WebRequest -UseBasicParsing -Uri $url
}

function get-version-format {
    param (
        [string]$page
    )
    $format = "\d+\.\d+\.\d+"
    $versiones = [regex]::Matches($page, $format) | ForEach-Object {$_.Value}
    # Eliminar duplicados y ordenar las versiones de mayor a menor
    return $versiones | Sort-Object { [System.Version]$_ } -Descending | Get-Unique
}

function quit-V([string]$version) {
    return $version -replace "^v", ""
}

$puertosReservados = @(
    @{ Servicio = "FTP"; Puerto = 21 },
    @{ Servicio = "SSH"; Puerto = 22 },
    @{ Servicio = "Telnet"; Puerto = 23 },
    @{ Servicio = "HTTP"; Puerto = 80 },
    @{ Servicio = "HTTPS"; Puerto = 443 },
    @{ Servicio = "SMPT"; Puerto = 25 },
    @{ Servicio = "MySQL"; Puerto = 3306 },
    @{ Servicio = "SQL Server"; Puerto = 1433 }
)

function VerifyPortsReserved {
    param (
        [int]$port
    )

    $puertoEncontrado = $puertosReservados | Where-Object { $_.Puerto -eq $port}

    if ($puertoEncontrado) {
        return $true
    } else {
        return $false
    }
}