<#
.SYNOPSIS
Identifies a .NET solution in the provodied path and opens it in the default
editor.

.DESCRIPTION
Searches for solution files in the provided path, for both the standard format
and the newer SLNX format. If multiple are found, the latter format is preferred
first, then the first identified file is used. The resulting file is finally
opened in the default editor by file type.

.PARAMETER Path
The base path to use for the solution file search.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '.'
)

$absolutePath = Resolve-Path -Path $Path
if (-not (Test-Path -Path $absolutePath)) {
    throw "No directory was found at '$Path'."
}

$solutions = Get-ChildItem -Path "$Path/*" -Include @('*.slnx', '*.sln')
if ($solutions.Length -eq 0) {
    throw "No solutions were found in '$Path'."
}

$preferredSolution = $solutions |
    Sort-Object -Property @(
        @{ Expression = 'Extension'; Descending = $true },
        @{ Expression = { $_.Name.Length }}
    ) |
    Select-Object -First 1

Invoke-Item -Path $preferredSolution.FullName
