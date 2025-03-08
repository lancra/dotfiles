[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path,

    [switch] $Staged
)

$diffPath = $Path ? $Path : $null
$stagedOption = $Staged ? ' --staged' : ''
$diffCommand = [scriptblock]::Create("git diff$stagedOption $diffPath")
$diffQuietCommand = [scriptblock]::Create("git diff$stagedOption --quiet --exit-code $diffPath")

$stopwatch = [System.Diagnostics.Stopwatch]::new()
$stopwatch.Start()

Invoke-Command -ScriptBlock $diffCommand
Invoke-Command -ScriptBlock $diffQuietCommand
$hasDifferences = $LASTEXITCODE -ne 0

$stopwatch.Stop()
Write-Output "Elapsed=$($stopwatch.Elapsed)"

Write-Output ''
# Write-Output "GitOutput='$diffOutput'"
Write-Output "GitOutput='$hasDifferences'"
Write-Output "What do?"
