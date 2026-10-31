Import-Module HackF5.ProfileAlias

$aliasSpecification = Get-Content -Path "$env:XDG_CONFIG_HOME/powershell/aliases.json" |
    ConvertFrom-Json

$aliasSpecification |
    Select-Object -ExpandProperty 'add' |
    ForEach-Object { $_.PSObject.Properties } |
    ForEach-Object {
        if ($_.Value.bash) {
            Set-ProfileAlias -Name $_.Name -Command $_.Value.command -Bash -Force | Out-Null
        } else {
            $command = $ExecutionContext.InvokeCommand.ExpandString($_.Value.command)
            Set-Alias -Name $_.Name -Value $command | Out-Null
        }
    }

$aliasSpecification |
    Select-Object -ExpandProperty 'remove' |
    ForEach-Object { $_.PSObject.Properties } |
    ForEach-Object {
        Remove-Alias -Name $_.Name -Force -ErrorAction SilentlyContinue
    }
