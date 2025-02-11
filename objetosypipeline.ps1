Get-Service -Name "LSM" | Get-Member

Get-Service -Name "LSM" | Get-Member -MemberType Property

Get-Item .\test.txt | Get-Member -MemberType Method

Get-Item .\test.txt | Select-Object Name, Length

Get-Service | Select-Object -Last 5

Get-Service | Select-Object -First 5

Get-Service | Where-Object {$_.Status -eq "Running"}

(Get-Item .\test.txt).IsReadOnly = 0
(Get-Item .\test.txt).IsReadOnly
(Get-Item .\test.txt).IsReadOnly = 1 
(Get-Item .\test.txt).IsReadOnly

Get-ChildItem *.txt

(Get-Item .\test.txt).CopyTo("C:\Users\Victor Ruiz\OneDrive\Documentos\GitHub\adminsys-302\prueba.txt")

Set-ItemProperty -Path .\test.txt -Name IsReadOnly -Value $false #cambiar los permisos para que me deje eliminar el archivo

(Get-Item .\test.txt).Delete()
Get-ChildItem *.txt

$miObjeto = New-Object PSObject
$miObjeto | Add-Member -MemberType NoteProperty -Name Nombre -Value "Miguel"
$miObjeto | Add-Member -MemberType NoteProperty -Name Edad -Value 23
$miObjeto | Add-Member -MemberType NoteProperty -Name Saludar -Value {Write-Host "Hola Mundo"}

$miObjeto =New-Object -TypeName PSObject -Property @{
    Nombre = "Miguel"
    Edad = 23
}
$miObjeto | Add-Member -MemberType ScriptMethod -Name Saludar -Value { Write-Host "Hola Mundo" }
$miObjeto | Get-Member

$miObjeto = [PSCustomObject] @{

    Nombre = "Miguel"
    Edad = 23
}
$miObjeto | Add-Member -MemberType ScriptMethod -Name Saludar -Value { Write-Host "Hola Mundo" }
$miObjeto | Get-Member4

Get-Process -Name Acrobat | Stop-Process

Get-Help -Full Get-Process

Get-Help -Full Stop-Process

Get-Process

Get-Process -Name Acrobat | Stop-Process

Get-Help -Full Get-ChildItem

Get-Help -Full Get-Clipboard

Get-ChildItem *txt | Get-Clipboard
System.String[]

Get-Help -Full Stop-Service

Get-Service
Get-Service Spooler | Stop-Service
Get-Service

Get-Service
"Spooler" | Stop-Service
Get-Service 
Get-Service

Get-Service
$miObjeto = [PSCustomObject] @{
    Name = "Spooler"
    }
    $miObject | Stop-Service

Get-Service
Get-Service