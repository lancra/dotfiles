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
