[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

& $PSScriptRoot/get-packages.ps1 |
    Select-Object -Property Id,Path |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target
