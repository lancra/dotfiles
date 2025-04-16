[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [uri] $Repository
)

if ($Repository.Host -ne 'github.com') {
    throw 'Only GitHub-based remotes are currently supported for latest tag retrieval.'
}

$id = & $PSScriptRoot/get-repository-id.ps1 -Repository $Repository

$latestReleaseCommandParts = @(
    'gh release list',
    "--repo $id",
    '--limit 1',
    '--json tagName',
    '--exclude-drafts',
    '--exclude-pre-releases'
)
$latestReleaseCommand = [scriptblock]::Create($latestReleaseCommandParts -join ' ')
Invoke-Command -ScriptBlock $latestReleaseCommand |
    ConvertFrom-Json |
    Select-Object -ExpandProperty tagName
