$condicion = $true 
if($condicion)
{
    Write-Output "La condicion era verdadera"
}
else {
    Write-Output "La condicion era falsa"
}

$numero = 2
if ($numero -ge 3)
{
    Write-Output "El numero [$numero] es mayor o igual que 3"
}
elseif ($numero -lt 2) 
{
    Write-Output "El numero [$numero] es menor que 2"
}
else
{
    Write-Output "El numero [$numero] es igual a 2"
}

switch (3) {
    1 {"[$_] es uno"}
    2 {"[$_] es dos"}
    3 {"[$_] es tres"}
    4 {"[$_] es cuatro"}
}

switch (3) {
    1 {"[$_] es uno"}
    2 {"[$_] es dos"}
    3 {"[$_] es tres"}
    4 {"[$_] es cuatro"}
    3 {"[$_] es tres de nuevo"}
}

switch (3) {
    1 {"[$_] es uno"}
    2 {"[$_] es dos"}
    3 {"[$_] es tres"; Break}
    4 {"[$_] es cuatro"}
    3 {"[$_] es tres de nuevo"}
}

switch (3, 5) {
    1 {"[$_] es uno"}
    2 {"[$_] es dos"}
    3 {"[$_] es tres"}
    4 {"[$_] es cuatro"}
    5 {"[$_] es cinco"}
}

switch ("seis")
{
    1 {"[$_] es uno"; Break}
    2 {"[$_] es dos"; Break}
    3 {"[$_] es tres"; Break}
    4 {"[$_] es cuatro"; Break}
    5 {"[$_] es cinco"; Break}
    "se*" {"[$_] coincide con se*"}
    Default {
        "No hay coincidencias con [$_]"
    }
}

switch -Wildcard ("seis")
{
    1 {"[$_] es uno"; Break}
    2 {"[$_] es dos"; Break}
    3 {"[$_] es tres"; Break}
    4 {"[$_] es cuatro"; Break}
    5 {"[$_] es cinco"; Break}
    "se*" {"[$_] coincide con se*"}
    Default {
        "No hay coincidencias con [$_]"
    }
}

$email = "antonio.yanez@udc.es"
$email2 = "antonio.yanez@usc.gal"
$url = "https://www.dc.fi.udc.es/~afyanez/docenncia/2023"
switch -Regex ($url, $email, $email2)
{
    "^\w+\.\w+@(udc|usc|edu)\.es|gal$" {"[$_] es una direccion de correo electronico academica"}
    "^ftp\://.*$" {"[$_] es una direccion ftp"}
    "^(http[s]?)\://.*$" {"[$_] es una direccion web, que utiliza [$($matches[1])]"}
}

1 -eq "1.0"
"1.0" -eq 1