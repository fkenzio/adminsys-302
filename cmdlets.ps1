Get-Command -Type Cmdlet | Sort-Object -Property Noun | Format-Table -GroupBy Noun

Get-Command -Name Get-ChildItem -Args Cert: -Syntax

Get-Command -Name dir

Get-Command -Noun WSManInstance