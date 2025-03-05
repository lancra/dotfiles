Import-Module HackF5.ProfileAlias
Get-Content -Path "$env:XDG_CONFIG_HOME/powershell/aliases.json" |
    ConvertFrom-Json |
    ForEach-Object { $_.PSObject.Properties } |
    Where-Object { -not $_.Name.StartsWith('$') } |
    ForEach-Object {
        if ($_.Value.bash) {
            Set-ProfileAlias -Name $_.Name -Command $_.Value.command -Bash -Force | Out-Null
        } else {
            $command = $ExecutionContext.InvokeCommand.ExpandString($_.Value.command)
            Set-Alias -Name $_.Name -Value $command | Out-Null
        }
    }
