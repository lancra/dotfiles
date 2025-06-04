<#
.SYNOPSIS
Changes the working directory to the root of the current Git repository.

.DESCRIPTION
Checks whether the current working directory exists within a Git repository, and
throws an error if not. If it does, the relative path is used to change
directories up the required depth.
#>
[CmdletBinding()]
param()

$currentRootRelativePath = & git rev-parse --show-prefix 2> $null
if ($LASTEXITCODE -eq 128) {
    throw 'The working directory is not part of a Git repository.'
}

$depth = ($currentRootRelativePath.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)).Length
& $PSScriptRoot/change-directory-up.ps1 -Count $depth
