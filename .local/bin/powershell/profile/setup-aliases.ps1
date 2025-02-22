Import-Module HackF5.ProfileAlias
Get-Content -Path "$env:XDG_CONFIG_HOME/powershell/aliases.json" |
    ConvertFrom-Json |
    ForEach-Object { $_.PSObject.Properties } |
    ForEach-Object {
        Set-ProfileAlias -Name $_.Name -Command $_.Value.command -Bash:$_.Value.bash -Force | Out-Null
    }
