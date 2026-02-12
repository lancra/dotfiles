<#
.SYNOPSIS
Changes the working directory to the root of the current Git repository.

.DESCRIPTION
Checks whether the current working directory exists within a Git repository, and
throws an error if not. If it does, the current directory is changed to the
repository root.
#>
[CmdletBinding()]
param()

$repositoryRoot = & "$env:BIN/git/get-repository-root.ps1"
Set-Location -Path $repositoryRoot
