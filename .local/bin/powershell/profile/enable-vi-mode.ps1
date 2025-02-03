Set-PSReadLineOption -EditMode Vi -ViModeIndicator Cursor
Set-PSReadLineKeyHandler -Key '*,y' -BriefDescription 'global yank' -ViMode Command -Scriptblock {
    param($key, $arg)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    Set-Clipboard -Value $line
}
