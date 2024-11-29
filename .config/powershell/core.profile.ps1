[console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

Set-PSReadLineOption -EditMode Vi -ViModeIndicator Cursor
Set-PSReadLineKeyHandler -Key '*,y' -BriefDescription 'global yank' -ViMode Command -Scriptblock {
    param($key, $arg)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    Set-Clipboard $line
}

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
        dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

Import-Module 'Lance'

Import-Module HackF5.ProfileAlias
Set-ProfileAlias cm 'check-machine.ps1' -Force | Out-Null
Set-ProfileAlias cmi '& check-machine.ps1 -Interactive' -Bash -Force | Out-Null
Set-ProfileAlias em 'export-machine.ps1' -Force | Out-Null
Set-ProfileAlias um 'update-machine.ps1' -Force | Out-Null
Set-ProfileAlias uem '& update-machine.ps1 && & export-machine.ps1' -Bash -Force | Out-Null

Set-ProfileAlias cwd '$pwd.Path | Set-Clipboard' -Bash -Force | Out-Null
Set-ProfileAlias g 'git #{:*}' -Bash -Force | Out-Null
Set-ProfileAlias iev 'import-environment-variables.ps1' -Force | Out-Null
Set-ProfileAlias jqf 'Set-Content -Path "$(#{0})" -Value (jq ''.'' "$(#{0})")' -Bash -Force | Out-Null
Set-ProfileAlias l 'lsd -l #{:*}' -Bash -Force | Out-Null
Set-ProfileAlias rmr 'Remove-Item -Path #{0} -Recurse' -Bash -Force | Out-Null
Set-ProfileAlias wu 'winget upgrade #{:*}' -Bash -Force | Out-Null

Import-Module 'posh-git'
oh-my-posh init pwsh --config "$env:XDG_CONFIG_HOME/powershell/lancra.omp.json" | Invoke-Expression
