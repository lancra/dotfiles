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

$variables = & "$env:BIN/powershell/convert-to-hashtable.ps1" -FlattenSeparator '_' -Object ($aliases |
    Select-Object -ExpandProperty 'variables')

# NOTE: This handles two-level variable definitions. If additional levels are used (e.g. a uses b which uses c), a topological sort or
#       stack must be implemented to process token replacements in the correct order.
$variableNames = $variables.GetEnumerator() |
    Select-Object -ExpandProperty Name
$variableNames |
    ForEach-Object {
        $variableTokens = @(& "$env:BIN/get-tokens.ps1" -Text $variables[$_] |
            Select-Object -ExpandProperty Key)
        if ($variableTokens) {
            $variables[$_] = & "$env:BIN/replace-tokens.ps1" -Text $variables[$_] -Token $variables
        }
    }

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
