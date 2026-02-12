[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter()]
    [string] $Path = $PWD
)

$repositoryRoot = git -C $Path rev-parse --show-toplevel 2> $null
if ($LASTEXITCODE -eq 128) {
    throw "The provided path '$Path' is not a Git repository."
}

$repositoryRoot
