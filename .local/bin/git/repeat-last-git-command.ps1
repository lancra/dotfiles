[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string] $Command
)

$entryCount = 50
$historyEntries = Get-History -Count $entryCount |
    Sort-Object -Property Id -Descending

$gitExecutables = @('g', 'git')
$lastCommandText = $null
foreach ($entry in $historyEntries) {
    foreach ($executable in $gitExecutables) {
        $executablePrefix = "$executable "
        if ($entry.CommandLine.StartsWith($executablePrefix)) {
            $lastCommandText = $entry.CommandLine.Substring($executablePrefix.Length)
            break
        }
    }

    if ($null -ne $lastCommandText) {
        break
    }
}

if ($null -eq $lastCommandText) {
    "$($PSStyle.Foreground.BrightRed)No Git commands found in the last $entryCount PowerShell history entries.$($PSStyle.Reset)" |
        Write-Output
    exit 1
}

Write-Verbose "git $lastCommandText"
$lastCommandSegments = $lastCommandText.Split(' ')
if ($Command) {
    $lastCommandSegments[0] = $Command
}

$nextCommandText = (@('git') + $lastCommandSegments) -join ' '
$nextCommand = [scriptblock]::Create($nextCommandText)
if ($PSCmdlet.ShouldProcess('working directory', $nextCommandText)) {
    Invoke-Command -ScriptBlock $nextCommand
}
