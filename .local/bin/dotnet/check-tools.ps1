[CmdletBinding()]
param()

& dotnet-tools-outdated --format json --noIndent |
    ConvertFrom-Json |
    Select-Object -ExpandProperty dotnet-tools-outdated |
    ForEach-Object {
        [ordered]@{
            provider = 'dotnet'
            id = $_.packageName
            current = $_.currentVer
            available = $_.availableVer
        }
    } |
    ConvertTo-Json -AsArray
