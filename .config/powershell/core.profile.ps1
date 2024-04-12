Import-Module 'Lance'

# Bash shortcuts
Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardKillLine
Set-PSReadLineKeyHandler -Chord Ctrl+k -Function ForwardDeleteLine

Import-Module HackF5.ProfileAlias
Set-ProfileAlias l 'lsd -l #{:*}' -Bash -Force | Out-Null

Import-Module 'posh-git'
oh-my-posh init pwsh --config "$env:XDG_CONFIG_HOME/powershell/lancra.omp.json" | Invoke-Expression
