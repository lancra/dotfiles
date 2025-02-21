using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path
)

if (-not $Path) {
    $callStackFrames = Get-PSCallStack
    if ($callStackFrames -and
        $callStackFrames -is [array] -and
        $callStackFrames.Length -gt 1) {
        $Path = $callStackFrames[1].ScriptName
    }
}

if (-not $Path) {
    throw 'No path was provided and the script was unable to determine the caller path using the call stack.'
}

$uri = [Uri]::new($Path)
$identifierSegments = $uri.Segments[-2..-1]

$providerSegment = $identifierSegments[0]
$provider = $providerSegment.Substring(0, $providerSegment.Length - 1)

$exportSegment = $identifierSegments[1]
$exportFileName = $exportSegment -replace '.ps1', ''
$exportFileNameSegments = $exportFileName -split '-'
$export = $exportFileNameSegments[1..($exportFileNameSegments.Length - 1)] -join '-'

$exportDefinition = & $PSScriptRoot/get-exports.ps1 -Provider $provider -Name $export
if (-not $exportDefinition) {
    throw "Unable to find definition for $export export in $provider provider."
}

$exportDefinition.Id
