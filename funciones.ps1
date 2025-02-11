Get-Verb

function Get-Fecha
{
Get-Date
}
Get-Fecha

Get-ChildItem -Path Function:\Get-*

Get-ChildItem -Path Function:\Get-Fecha | Remove-Item
Get-ChildItem -Path Function:\Get-*

function Get-Resta {
Param ([int]$num1, [int]$num2)
$resta=$num-$num2
Write-Host "La resta de los parametros es $resta"
}

Get-resta 10 5

Get-resta -num2 10 -num1 5

Get-resta -num2 10

function Get-Resta {
Param ([Parameter(Mandatory)][int]$num1, [int]$num2)
$resta=$num1-$num2
Write-Host "La resta de los parametros es $resta"
}
Get-Resta -num2 10

function Get-Resta {
[CmdletBinding()]
Param ([int]$num1, [int]$num2)
$resta=$num1-$num2
Write-Host "La resta de los parametros es $resta"
}

(Get-Command -Name Get-Resta).Parameters.Keys

function Get-Resta {
[CmdletBinding()]
Param ([int]$num1, [int]$num2)
$resta=$num1-$num2 #Operacion que realiza la resta
Write-Host"La resta de los parametros es $resta"
}

function Get-Resta {
[CmdletBinding()]
Param ([int]$num1, [int]$num2)
$resta=num1-$num2
Write-Verbose -Message "Operacion que va a realizar una resta de $num1 y $num2"
Write-Host "La resta de los parametros es $resta"
}
Get-Resta 10 5 -Verbose