[CmdletBinding()]
param()

$registries = @(
    'mcr.microsoft.com'
)

& "$PSScriptRoot/get-images.ps1" |
    Where-Object { $registries -contains $_.Registry } |
    ForEach-Object {
        & "$PSScriptRoot/cache-digests-from-registry.ps1" -Registry $_.Registry -Repository $_.Repository
    }
