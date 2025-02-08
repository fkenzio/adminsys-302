$variable = "hola"
$variable2 = " que tal?"
$variable3 = 100
$variable4 = 200

New-Variable -Name variable5 -Value 300
$variable5 

$variable
$variable2
$variable3
$variable4

$variable+$variable2
$variable3+$variable4
$variable3 - $variable4

$$

$^

$?

$Error

get-help about_automatic_variables

$ConfirmPreference
$DebugPreference

$ErrorActionPreference
$WarningPreference