Write-Host "Instalando el rol de servidor DHCP..."
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Write-Host "Rol de servidor DHCP instalado correctamente"

Add-DhcpServerInDC -DnsName WIN-U3GU7HU64NR.WORKGROUP -IPAddress 192.168.0.90 

Add-DHCPServerV4Scope
Set-DHCPServerV4OptionValue -ScopeId 192.168.0.0 -DnsServer 8.8.8.8 -Router 192.168.0.1

Restart-Service dhcpserver
Write-Host "Configuracion completada. El servicio DHCP se ha reiniciado correctamente"