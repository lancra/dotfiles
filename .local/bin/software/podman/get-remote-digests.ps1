[CmdletBinding()]
[OutputType([hashtable])]
param(
    [Parameter(Mandatory)]
    [string] $Registry,

    [Parameter()]
    [string] $Namespace,

    [Parameter(Mandatory)]
    [string] $Repository
)

function Get-DockerHubDigests {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    process {
        $tagsByDigest = @{}
        $url = "https://hub.docker.com/v2/namespaces/$Namespace/repositories/$Repository/tags?page_size=100"
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
        $cacheFileName = $Repository.Replace('/', '-')
        $cacheFilePath = "$env:XDG_CACHE_HOME/image-digests/$Registry/$cacheFileName.json"
        if (-not (Test-Path -Path $cacheFilePath)) {
            & "$PSScriptRoot/cache-digests-from-registry.ps1" -Registry $Registry -Repository $Repository
        }

        Get-Content -Path $cacheFilePath |
            ConvertFrom-Json -AsHashtable
    }
}

switch ($Registry) {
    'docker.io' { return Get-DockerHubDigests }
    'mcr.microsoft.com' { return Get-CachedDigests }
}

Write-Warning "Unknown podman image registry '$Registry'."
return @{}
