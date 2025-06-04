<#
.SYNOPSIS
Verifies the presence of a remote HEAD ref for all Git repositories in the
provided path.

.DESCRIPTION
For each child directory in the provided path, the existence of a .git directory
is checked first. If missing, the repository is denoted as uninitialized. If the
origin remote ref directory is not found, the repository is denoted as local. If
the HEAD ref is missing from the remote directory, the repository is denoted as
missing. Otherwise, the repository is denoted as present.

.PARAMETER Path
The directory to retrieve Git repositories from. The working directory is used
when this is not provided.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '.'
)

Get-ChildItem -Path $Path -Directory |
    ForEach-Object {
        $repositoryName = [System.IO.Path]::GetFileName($_)
        Write-Host "${repositoryName}: " -NoNewline

        $gitDirectory = Join-Path -Path $_ -ChildPath '.git'
        if (-not (Test-Path -Path $gitDirectory)) {
            Write-Host 'Uninitialized' -ForegroundColor 'Yellow'
            return
        }

        $originRemotePath = Join-Path -Path $gitDirectory -ChildPath 'refs' -AdditionalChildPath 'remotes', 'origin'
        if (-not (Test-Path -Path $originRemotePath)) {
            Write-Host 'Local' -ForegroundColor 'Magenta'
            return
        }

        $originRemoteHeadPath = Join-Path -Path $originRemotePath -ChildPath 'HEAD'
        $hasRemoteHead = Test-Path -Path $originRemoteHeadPath

        if ($hasRemoteHead) {
            Write-Host 'Present' -ForegroundColor 'Green'
        } else {
            Write-Host 'Missing' -ForegroundColor 'Red'
        }
    }
