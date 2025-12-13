<#
.SYNOPSIS
Generates a Git configuration file for aliases specified in the tracked file.

.DESCRIPTION
For each element in the JSON configuration file containing extended alias
definitions, any variable tokens are replaced with the appropriate value. The
resulting key-value is written to the Git configuration file.
#>
[CmdletBinding()]
param()

$gitConfigurationDirectory = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'git'
$sourcePath = Join-Path -Path $gitConfigurationDirectory -ChildPath 'aliases.json'
$targetPath = Join-Path -Path $gitConfigurationDirectory -ChildPath 'alias.gitconfig'

$builder = [System.Text.StringBuilder]::new()
[void]$builder.Append('[alias]')

$aliases = Get-Content -Path $sourcePath |
    ConvertFrom-Json

$variables = & "$env:BIN/powershell/convert-to-hashtable.ps1" -Object ($aliases |
    Select-Object -ExpandProperty 'variables')

$aliasCount = 0
$aliases.definitions.PSObject.Properties |
    ForEach-Object {
        $key = $_.Name
        $body = & "$env:BIN/replace-tokens.ps1" -Text $_.Value.body -Token $variables

        [void]$builder.Append("$([System.Environment]::NewLine)`t$key = `"$body`"")
        $aliasCount++
    }

Write-Verbose "Writing $aliasCount Git aliases."
Set-Content -Path $targetPath -Value $builder.ToString()
