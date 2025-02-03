Import-Module HackF5.ProfileAlias
Get-Content -Path "$env:XDG_CONFIG_HOME/powershell/aliases.json" |
    ConvertFrom-Json |
    ForEach-Object {
        $bash = [bool]::Parse($_.bash)
        Set-ProfileAlias -Name $_.name -Command $_.command -Bash:$bash -Force | Out-Null
    }
