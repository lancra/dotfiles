[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [uri] $Repository
)

(($Repository.Segments | Select-Object -Last 2) -join '').TrimEnd('.git')
