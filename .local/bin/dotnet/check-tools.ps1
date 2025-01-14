[CmdletBinding()]
param()

& dotnet-tools-outdated --format json --noIndent --outPkgRegardlessState |
    ConvertFrom-Json |
    Select-Object -ExpandProperty dotnet-tools-outdated |
    ForEach-Object {
      if ($_.currentVer -ne $_.availableVer) {
        [ordered]@{
            provider = 'dotnet'
            id = $_.packageName
            current = $_.currentVer
            available = $_.availableVer
        }
      }
    } |
    ConvertTo-Json -AsArray
