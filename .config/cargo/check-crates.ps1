[CmdletBinding()]
param()

& $PSScriptRoot/get-crates.ps1 |
    ForEach-Object {
        if ($_.Current -ne $_.Available) {
            [ordered]@{
                provider = 'cargo'
                id = $_.Id
                current = $_.Current
                available = $_.Available
            }
        }
    } |
    ConvertTo-Json -AsArray
