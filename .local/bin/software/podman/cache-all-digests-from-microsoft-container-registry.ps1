[CmdletBinding()]
param()

& "$PSScriptRoot/get-images.ps1" |
    Where-Object -Property Registry -EQ 'mcr.microsoft.com' |
    ForEach-Object {
        & "$PSScriptRoot/cache-digests-from-microsoft-container-registry.ps1" -Repository $_.Repository
    }
