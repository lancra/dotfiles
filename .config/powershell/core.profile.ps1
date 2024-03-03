Import-Module 'Lance'

# Bash shortcuts
Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardKillLine
Set-PSReadLineKeyHandler -Chord Ctrl+k -Function ForwardDeleteLine

# Aliases
function l {
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    process {
        lsd -l $Arguments
    }
}

Import-Module 'posh-git'
oh-my-posh init pwsh --config "$env:XDG_CONFIG_HOME/powershell/lancra.omp.json" | Invoke-Expression
