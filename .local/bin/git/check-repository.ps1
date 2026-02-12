[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = $PWD
)

# Retrieving the root will throw when the path is not a Git repository.
& $PSScriptRoot/get-repository-root.ps1 -Path $Path | Out-Null
