[CmdletBinding()]
[OutputType([hashtable])]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

$image = & "$PSScriptRoot/parse-image-id.ps1" -Id $Id

function Get-DockerHubDigests {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    process {
        $tagsByDigest = @{}
        $url = "https://hub.docker.com/v2/namespaces/$($image.Namespace)/repositories/$($image.Repository)/tags?page_size=100"
        do {
            $response = & curl --silent $url |
                ConvertFrom-Json

            $response |
                Select-Object -ExpandProperty 'results' |
                ForEach-Object {
                    $digest = $_.digest ?? $_.images[0].digest

                    if (-not $tagsByDigest.ContainsKey($digest)) {
                        $tagsByDigest[$digest] = @()
                    }

                    if ($_.name -eq 'latest') {
                        $tagsByDigest['@latest'] = $digest
                    }

                    $tagsByDigest[$digest] += ,$_.name
                }

            $url = $response |
                Select-Object -ExpandProperty 'next'
        }
        while ($null -ne $url)

        $tagsByDigest
    }
}

function Get-CachedDigests {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    process {
        $fullRepository = $image.Repository
        if (-not [string]::IsNullOrEmpty($image.Namespace)) {
            $fullRepository = "$($image.Namespace)/$fullRepository"
        }

        $cacheFileName = $fullRepository.Replace('/', '-')
        $cacheFilePath = "$env:XDG_CACHE_HOME/image-digests/$($image.Registry)/$cacheFileName.json"
        if (-not (Test-Path -Path $cacheFilePath)) {
            & "$PSScriptRoot/cache-digests-from-registry.ps1" -Registry $image.Registry -Repository $fullRepository
        }

        Get-Content -Path $cacheFilePath |
            ConvertFrom-Json -AsHashtable
    }
}

switch ($image.Registry) {
    'docker.io' { return Get-DockerHubDigests }
    'mcr.microsoft.com' { return Get-CachedDigests }
}

Write-Warning "Unknown podman image registry '$($image.Registry)'."
return @{}
