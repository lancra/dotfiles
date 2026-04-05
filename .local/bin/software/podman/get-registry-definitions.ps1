[CmdletBinding()]
[OutputType([psobject[]])]
param(
    [Parameter()]
    [string] $Uri,

    [Parameter()]
    [ValidateSet('api', 'cache')]
    [string] $DigestStorage
)

$properties = @(
    @{ Name = 'Uri'; Expression = { $_.uri } },
    @{ Name = 'Name'; Expression = { $_.name } },
    @{ Name = 'ScriptName'; Expression = { $_.scriptName } },
    @{ Name = 'Authentication'; Expression = { $_.authentication } },
    @{ Name = 'DigestStorage'; Expression = { $_.digestStorage } }
)
Get-Content -Path "$env:XDG_CONFIG_HOME/software/podman.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'registries' |
    Select-Object -Property $properties |
    Where-Object { [string]::IsNullOrEmpty($Uri) -or $_.Uri -eq $Uri } |
    Where-Object { [string]::IsNullOrEmpty($DigestStorage) -or $_.DigestStorage -eq $DigestStorage }
