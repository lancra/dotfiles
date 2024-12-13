[CmdletBinding()]
[OutputType([string[]])]
param()

$keys = @('source')

$keys += Get-Content -Path "$env:XDG_CONFIG_HOME/snippets/config.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty editors |
    Select-Object -ExpandProperty key |
    ForEach-Object {
        if (Test-Path -Path "$env:HOME/.local/bin/snippets/$_/compare-snippet.ps1") {
            return $_
        }
    }

$keys |
    Sort-Object
