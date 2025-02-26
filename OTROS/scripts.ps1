cat .\try-catch.ps1
try
{
    Write-Output "Todo bien"
}
catch
{
    Write-Output "Algo lanzo una excepcion"
    Write-Output $_
}

try
{
    Start-Something -ErrorAction Stop
}
catch
{
    Write-Output "Algo genero una excepcion o uso Write-Error"
    Write-Output $_
}
.\try-catch.ps1

cat .\trap.ps1
trap
{
    Write-Output $PSItem.ToString()
}
throw [System.Exception]::new('primero')
throw [System.Exception]::new('segundo')
throw [System.Exception]::new('tercero')
.\trap.ps1

ls
Import-Module BackupRegistry

Get-Help Backup-Registry

Backup-Registry -rutaBackup 'D:\tmp\Backup\Registro\'
ls -\tmpBackup\Registro

vim .\Backup-Registry.ps1
Import-Module BackupRegistry -Force
Backup-Registry -rutaBackup 'D:\tmp\Backup\Registro\'
ls 'D:\tmp\Backup\Registro\'

ls 'D:\tmp\Backup\Registro\'
Get-Date
ls 'D:\tmp\Backup\Registro\'

Get-ScheduledTask

Unregister-ScheduledTask 'Ejecutar Backup del Registro del Sistema'

Get-ScheduledTask


