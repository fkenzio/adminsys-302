Import-Module "C:\Users\Victor Ruiz\OneDrive\Documentos\GitHub\adminsys-302\FUNCIONES.ps1"

Install-WindowsFeature -Name DNS -IncludeManegementTools

$DATOS = Solicitar-Datos
$Dominio = $DATOS.Dominio
$IP = $DATOS.IP

if (-not (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue))
{
	Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns"
	Write-Host "Zone DNS '$Dominio' creada correctamente"
} else {
	Write-Host "La zona '$Dominio' ya existe"
}

DnsServerResourceRecordA -ZoneName $Dominio -Name "@" -IPv4Address $IP
Write-Host "Registro A para '$Dominio' agregada correctamente"


DnsServerResourceRecordA -ZoneName $Dominio -Name "www" -IPv4Address $IP
Write-Host "Registro A para 'www.$Dominio' agregado correctamente"

Set-DnsClientServerAddress -InterfaceIndex 5 -ServerAddresses $IP

Restart-Service DNS
Write-Host "Configuracion DNS completada con exito"