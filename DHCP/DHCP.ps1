Write-Host "Instalando el rol de servidor DHCP..."
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Write-Host "Rol de servidor DHCP instalado correctamente"

Add-DhcpServerInDC -DnsName WIN-U3GU7HU64NR.WORKGROUP -IPAddress 192.168.0.90 

Configurar_DHCP

Write-Host "Configuracion completada. El servicio DHCP se ha reiniciado correctamente"