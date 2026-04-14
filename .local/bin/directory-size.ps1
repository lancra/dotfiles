<#
.SYNOPSIS
Displays a user-friendly size for a provided directory.

.DESCRIPTION
Uses robocopy to determine the disk size and formats the resulting byte count.

.PARAMETER Path
The path of the directory to display size for.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '.'
)

$resolvedPath = Resolve-Path -Path $Path

$arguments = @(
    'robocopy',
    $resolvedPath,
    'NULL',
    '/L', # List only - don't copy, timestamp or delete any files.
    '/S', # copy Subdirectories, but not empty ones.
    '/BYTES', # Print sizes as bytes.
    '/NJH', # No Job Header.
    '/NDL', # No Directory List - don't log directory names.
    '/NFL', # No File List - don't log file names.
    '/XJ', # eXclude symbolic links (for both files and directories) and Junction points.
    '/R:0', # number of Retries on failed copies: default 1 million.
    '/W:0' # Wait time between retries: default is 30 seconds.
)

$command = [scriptblock]::Create($arguments)

Invoke-Command -ScriptBlock $command |
    ForEach-Object {
        if (-not $_.StartsWith('   Bytes :')) {
            return
        }

        $bytesSegments = $_.Substring($_.IndexOf(':') + 2) -split ' '
        $bytes = $bytesSegments[0]
        $size = & "$PSScriptRoot/get-byte-size.ps1" -Count $bytes -Format 'padded'
        "`e[93m$size`e[39m $resolvedPath"
    }
