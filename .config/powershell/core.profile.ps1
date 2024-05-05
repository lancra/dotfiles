Import-Module 'Lance'

Set-PSReadLineOption -EditMode Vi -ViModeIndicator Cursor
Set-PSReadLineKeyHandler -Key '*,y' -BriefDescription 'global yank' -ViMode Command -Scriptblock {
    param($key, $arg)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    Set-Clipboard $line
}

Import-Module HackF5.ProfileAlias
Set-ProfileAlias em 'export-machine.ps1' -Force | Out-Null
Set-ProfileAlias g 'git #{:*}' -Bash -Force | Out-Null
Set-ProfileAlias l 'lsd -l #{:*}' -Bash -Force | Out-Null
Set-ProfileAlias wu 'winget upgrade #{:*}' -Bash -Force | Out-Null

Import-Module 'posh-git'
oh-my-posh init pwsh --config "$env:XDG_CONFIG_HOME/powershell/lancra.omp.json" | Invoke-Expression
