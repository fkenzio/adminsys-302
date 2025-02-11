Get-Service

Get-Service -Name Spooler

Get-Service -DisplayName Hora*

Get-Service | Where-Object {$_.Status -eq "Running"}

Get-Service | Where-Object {$_.StartType -eq "Automatic"} | Select-Object Name, StartType

Get-Service -DependentServices Spooler

Get-Service -RequiredServices Fax

Stop-Service -Name Spooler -Confirm -PassThru

Start-Service -Name Spooler -Confirm -PassThru

Suspend-Service -Name stisvc -Confirm -PassThru

Get-Service | Where-Object CanPauseAndContinue -eq True

Suspend-Service -Name Spooler

Restart-Service -Name WSearch -Confirm -PassThru

Set-Service -Name dcsvc -DisplayName "Service de virtualizacion de credenciales de seguridad distribuidas"

Set-Service -Name BITS -StartupType Automatic -Confirm -PassThru | Select-Object Name, StartType 

Set-Service -Name BITS -Description "Transfiere archivos en segundo plano mediante el uso de ancho de banda de red inactivo."

Get-CimInstance Win32_Service -Filter 'Name = "BITS"' | Format-List Name, Description

Set-Service -Name Spooler -Status Running -Confirm -PassThru

Set-Service -Name stisvc -Status Paused -Confirm -PassThru

Set-Service -Name BITS -Status Stopped -Confirm -PassThru

Get-Process

Get-Process -Name Acrobat

Get-Process -Name Search*

Get-Process -Id 13948

Get-Process WINWORD -FileVersionInfo

Get-Process WINDORD -IncludeUserName

Get-Process WINWORD -Module

Stop-Process -Name Acrobat -Confirm -PassThru

Stop-Process -Id 10940 -Confirm -PassThru

Get-Process -Name Acrobat | Stop-Process -Confirm -PassThru

Start-Process -FilePath "C:\Windows\System32\notepad.exe" -PassThru

Start-Process -FilePath "cmd.exe" -ArgumentList "/c mkdir NuevaCarpeta" -WorkingDirectory "D:\Documents\FIC\Q6\ASO" -PassThru

Start Process -FilePath "notepad.exe" -WindowStyle "Maximized" -PassThru

Start-Process -FilePath "D:\Documents\FIC\Q6\ASO\TT\TT.txt" -Verb Print -PassThru

Get-Process -Name notep*
Wait-Process -Name notepad
Get-Process -Name notep*

Get-Process -Name notepad
Wait-Process -Id 11568
Get-Process -Name notep*

Get-Process -Name notep*
Get-Process -Name notepad | Wait-Process

Get-LocalUser

Get-LocalUser -Name Miguel | Select-Object *

Get-LocalUser -SID S-1-5-21-619924196-4045554399-1956444398-500 | Select-Object *

Get-LocalGroup

Get-LocalGroup -Name Administradores | Select-Object *

Get-LocalGroup -SID S-1-5-32-545 | Select-Object *

New-LocalUser -Name "Usuario1" -Description "Usuario de prueba 1" -NoPassword

New-LocalUser -Name "Usuario2" -Description "Usuario de prueba 2" -Password (ConvertTo- SecureString -AsPlainText "12345" -Force)

Get-LocalUser -Name "Usuario1"
Remove-LocalUser -Name "Usuario1"
Get-LocalUser -Name "Usuario1"

Get-LocalUser -Name "Usuario2"
Get-LocalUser -Name "Usuario2" | Remove-LocalUser
Get-LocalUser -Name "Usuario2"

New-LocalGroup -Name 'Grupo1' -Description 'Grupo de prueba 1'

Add-LocalGroupMember -Group Grupo1 -Member Usuario2 -Verbose

Get-LocalGroupMember Grupo1

Remove-LocalGroupMember -Group Grupo1 -Member Usuario1
Remove-LocalGroupMember -Group Grupo1- Member Usuario2
Get-LocalGroupMember Grupo1

Get-LocalGroup -Name "Grupo1"
Remove-LocalGroup -Name "Grupo1"
Get-LocalGroup -Name "Grupo1"

.\script.ps1

.\script.ps1
.\script.ps1
