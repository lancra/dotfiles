[CmdletBinding()]
[OutputType([string[]])]
param()

$keys = @('source')

$keys += Get-Content -Path "$env:SNIPPET_HOME/config.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty editors |
    Select-Object -ExpandProperty key |
    ForEach-Object {
        if (Test-Path -Path "$env:SNIPPET_HOME/.scripts/$_/compare-snippet.ps1") {
            return $_
        }
    }

$keys |
    Sort-Object
