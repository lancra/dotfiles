[CmdletBinding()]
param()

$currentRootRelativePath = & git rev-parse --show-prefix 2> $null
if ($LASTEXITCODE -eq 128) {
    throw 'The working directory is not part of a Git repository.'
}

$depth = ($currentRootRelativePath.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)).Length
& $PSScriptRoot/change-directory-up.ps1 -Count $depth
