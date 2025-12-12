[CmdletBinding()]
param()

$aliasesPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'powershell' -AdditionalChildPath 'aliases.json'
$aliases = Get-Content -Path $aliasesPath |
    ConvertFrom-Json
$aliases.PSObject.Properties |
    Where-Object { -not $_.Name.StartsWith('$') } |
    ForEach-Object {
        [pscustomobject]@{
            Group = $_.Value.group
            Key = $_.Name
            Command = $_.Value.command
            Bash = $_.Value.bash
        }
    }
