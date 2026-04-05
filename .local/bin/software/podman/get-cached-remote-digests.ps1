[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [psobject] $Image
)

$fullRepository = $Image.Repository
if (-not [string]::IsNullOrEmpty($Image.Namespace)) {
    $fullRepository = "$($Image.Namespace)/$fullRepository"
}

$cacheFileName = $fullRepository.Replace('/', '-')
$cacheFilePath = "$env:XDG_CACHE_HOME/image-digests/$($Image.Registry)/$cacheFileName.json"
if (-not (Test-Path -Path $cacheFilePath)) {
    & "$PSScriptRoot/cache-digests-from-registry.ps1" -Registry $Image.Registry -Repository $fullRepository
}

Get-Content -Path $cacheFilePath |
    ConvertFrom-Json -AsHashtable
