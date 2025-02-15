[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Target
)

& $PSScriptRoot/get-crates.ps1 |
    Select-Object -Property Id,Name,Description |
    Sort-Object -Property Name |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target
