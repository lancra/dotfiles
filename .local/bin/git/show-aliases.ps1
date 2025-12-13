[CmdletBinding()]
param(
    [switch] $ExpandVariables
)

$aliasesPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'git' -AdditionalChildPath 'aliases.json'
$aliases = Get-Content -Path $aliasesPath |
    ConvertFrom-Json

$variables = & "$env:BIN/powershell/convert-to-hashtable.ps1" -Object ($aliases |
    Select-Object -ExpandProperty 'variables')
$definitions = $aliases |
    Select-Object -ExpandProperty 'definitions'

$definitions.PSObject.Properties |
    ForEach-Object {
        $body = $_.Value.body
        if ($ExpandVariables) {
            $body = & "$env:BIN/replace-tokens.ps1" -Text $body -Token $variables
        }

        [pscustomobject]@{
            Title = $_.Value.title
            Key = $_.Name
            Body = $body
        }
    }
