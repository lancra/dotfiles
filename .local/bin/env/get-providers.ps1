[CmdletBinding()]
param(
    [Parameter()]
    [string]$Id
)

$providers = Get-Content -Path "$env:XDG_CONFIG_HOME/env/providers.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty providers

if ($Id) {
    $providers = $providers |
        Where-Object -Property id -EQ $Id
}

$providers
