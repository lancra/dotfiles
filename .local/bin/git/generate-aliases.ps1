[CmdletBinding()]
param()

$gitConfigurationDirectory = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'git'
$sourcePath = Join-Path -Path $gitConfigurationDirectory -ChildPath 'aliases.json'
$targetPath = Join-Path -Path $gitConfigurationDirectory -ChildPath 'alias.gitconfig'

$builder = [System.Text.StringBuilder]::new()
[void]$builder.Append('[alias]')

$aliases = Get-Content -Path $sourcePath |
    ConvertFrom-Json

$variables = @{}
$aliases.variables.PSObject.Properties |
    ForEach-Object {
        $variables[$_.Name] = $_.Value
    }

$tokenGroupKey = 'token'
$variablePattern = "(?<$tokenGroupKey>__.*?__)"
$aliasCount = 0
$aliases.definitions.PSObject.Properties |
    ForEach-Object {
        [PSCustomObject]@{
            Key = $_.Name
            Body = $_.Value.body
        }
    } |
    ForEach-Object {
        $body = $_.Body
        Select-String -InputObject $_.Body -Pattern $variablePattern -AllMatches |
            Select-Object -ExpandProperty Matches |
            ForEach-Object {
                $tokenGroup = $_.Groups |
                    Where-Object -Property Name -EQ $tokenGroupKey
                $token = $tokenGroup.Value.Trim('_')
                $value = $variables[$token]
                if ($null -eq $value) {
                    throw "No value specified for $token variable."
                }

                $body = $body.Replace($tokenGroup.Value, $value)
            }

        [void]$builder.Append("$([System.Environment]::NewLine)`t$($_.Key) = `"$body`"")
        $aliasCount++
    }

Write-Verbose "Writing $aliasCount Git aliases."
Set-Content -Path $targetPath -Value $builder.ToString()
