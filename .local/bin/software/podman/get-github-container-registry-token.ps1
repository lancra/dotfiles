[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string] $Repository
)

$getTokenCommandArguments = @(
    'curl',
    '--silent',
    "https://ghcr.io/token?scope='repository:${Repository}:pull'"
)

$getTokenCommand = [scriptblock]::Create("$getTokenCommandArguments")

Invoke-Command -ScriptBlock $getTokenCommand |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'token'
