[CmdletBinding()]
[OutputType([psobject[]])]
param(
    [Parameter()]
    [ValidateSet('api', 'cache')]
    [string] $DigestStorage
)

Get-Content -Path "$env:XDG_CONFIG_HOME/software/podman.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'registries' |
    Where-Object { [string]::IsNullOrEmpty($DigestStorage) -or $_.digestStorage -eq $DigestStorage }
