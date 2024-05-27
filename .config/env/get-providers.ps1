[CmdletBinding()]
param(
    [Parameter()]
    [string]$Id
)

$providers = Get-Content -Path "$PSScriptRoot/providers.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty providers

if ($Id) {
    $providers = $providers |
        Where-Object -Property id -EQ $Id
}

$providers
