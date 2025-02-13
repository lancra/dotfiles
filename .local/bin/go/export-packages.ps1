[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

& $PSScriptRoot/get-packages.ps1 |
    Select-Object -Property Id,Name,Module |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target
