[CmdletBinding()]
param()

$registryUris = & "$PSScriptRoot/get-registry-definitions.ps1" -DigestStorage 'cache' |
    Select-Object -ExpandProperty 'uri'

& "$PSScriptRoot/get-images.ps1" |
    Where-Object { $registryUris -contains $_.Registry } |
    ForEach-Object {
        $repository = $_.Repository
        if (-not [string]::IsNullOrEmpty($_.Namespace)) {
            $repository = "$($_.Namespace)/$repository"
        }

        & "$PSScriptRoot/cache-digests-from-registry.ps1" -Registry $_.Registry -Repository $repository
    }
