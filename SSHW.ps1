Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (ssh)' -Enable True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
Restart-Service sshd
Write-Output "Ya esta funcionando con toño y lupe"
