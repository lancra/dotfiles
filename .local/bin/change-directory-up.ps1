<#
.SYNOPSIS
Changes the working directory up a specified depth.

.DESCRIPTION
Generates a path with the provided number of parent directory symbols and
changes the working directory to that path.

.PARAMETER Count
The depth at which to change directories up. A single navigation is used when
this is not provided.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [int] $Count = 1
)

$segments = @()

for ($i = 0; $i -lt $Count; $i++) {
    $segments += '..'
}

$path = $segments -join '/'
Set-Location -Path $path
