<#
.SYNOPSIS
Rebuilds PowerShell aliases defined in the user profile.
.DESCRIPTION
Deletes the alias directory from local application data and reloads the profile.
#>
[CmdletBinding()]
param()

$aliasDirectoryPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'pshw'
$aliasesExist = Test-Path -Path $aliasDirectoryPath

if (-not $aliasesExist) {
    Write-Verbose 'No profile aliases were found, skipping deletion.'
} else {
    Write-Verbose 'Removing the profile alias directory.'
    Remove-Item -Path $aliasDirectoryPath -Recurse
}

Write-Verbose 'Dot sourcing the profile.'
. $PROFILE
