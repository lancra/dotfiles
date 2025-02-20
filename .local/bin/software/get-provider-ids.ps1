[CmdletBinding()]
param()

& $PSScriptRoot/get-providers.ps1 |
    Select-Object -ExpandProperty Id
