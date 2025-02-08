[CmdletBinding()]
param()

$gitConfigurationDirectory = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'git'
$sourcePath = Join-Path -Path $gitConfigurationDirectory -ChildPath 'aliases.json'
$targetPath = Join-Path -Path $gitConfigurationDirectory -ChildPath 'alias.gitconfig'

New-Item -ItemType File -Path $targetPath -Value "[alias]`r`n" -Force | Out-Null

$aliasesObject = Get-Content -Path $sourcePath |
    ConvertFrom-Json
$aliasesObject.PSObject.Properties |
    ForEach-Object {
        if ($_.Name -ne '$schema') {
            $key = $_.Name
            $body = $_.Value.body
            "`t$key = `"$body`""
        }
    } |
    Add-Content -Path $targetPath
