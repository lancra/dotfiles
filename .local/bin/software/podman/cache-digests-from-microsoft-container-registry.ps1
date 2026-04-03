[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Repository
)

function Get-RepositoryTagDigest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Url
    )
    process {
        $getDockerManifestCommandArguments = @(
            'curl',
            '--silent',
            "--header 'Accept: application/vnd.docker.distribution.manifest.v2+json'",
            "--write-out '{`"metadata`":%{json},`"headers`":%{header_json}}'",
            "--out-null",
            $Url
        )
        $getDockerManifestCommand = [scriptblock]::Create("$getDockerManifestCommandArguments")
        $dockerManifestResponse = Invoke-Command -ScriptBlock $getDockerManifestCommand |
            ConvertFrom-Json

        $dockerManifestStatusCode = $dockerManifestResponse |
            Select-Object -ExpandProperty 'metadata' |
            Select-Object -ExpandProperty 'http_code'
        if ($dockerManifestStatusCode -eq 200) {
            return $dockerManifestResponse |
                Select-Object -ExpandProperty 'headers' |
                Select-Object -ExpandProperty 'docker-content-digest'
        }

        $responsePath = "$([System.IO.Path]::GetTempFileName()).json"
        $getOciImageIndexCommandArguments = @(
            'curl',
            '--silent',
            "--header 'Accept: application/vnd.oci.image.index.v1+json'",
            "--output '$responsePath'",
            $Url
        )

        $getOciImageIndexCommand = [scriptblock]::Create("$getOciImageIndexCommandArguments")
        Invoke-Command -ScriptBlock $getOciImageIndexCommand

        $digestResponse = & sha256sum $responsePath
        Remove-Item -Path $responsePath

        $digestGroupName = 'digest'
        $digest = $digestResponse |
            Select-String -Pattern "\\(?<$digestGroupName>.*?) \*.*" |
            Select-Object -ExpandProperty Matches |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $digestGroupName |
            Select-Object -ExpandProperty Value
        return "sha256:$digest"
    }
}
$getRepositoryTagDigestFunction = ${function:Get-RepositoryTagDigest}.ToString()

$tagsByDigest = @{}
$tagProperties = @(
    @{ Name = 'Tag'; Expression = { $_ } },
    @{ Name = 'Url'; Expression = { "https://mcr.microsoft.com/v2/$Repository/manifests/$_" } }
)
& curl --silent "https://mcr.microsoft.com/v2/$Repository/tags/list" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'tags' |
    Select-Object -Property $tagProperties |
    ForEach-Object -Parallel {
        ${function:Get-RepositoryTagDigest} = $using:getRepositoryTagDigestFunction
        $digest = Get-RepositoryTagDigest -Url $_.Url

        [pscustomobject]@{
            Tag = $_.Tag
            Digest = $digest
        }
    } |
    ForEach-Object {
        if (-not $tagsByDigest.ContainsKey($_.Digest)) {
            $tagsByDigest[$_.Digest] = @()
        }

        if (@($_.Tag) -contains 'latest') {
            $tagsByDigest['@latest'] = $_.Digest
        }

        $tagsByDigest[$_.Digest] += ,$_.Tag
    }

$cacheDirectoryPath = "$env:XDG_CACHE_HOME/mcr.microsoft.com"
New-Item -ItemType Directory -Path $cacheDirectoryPath -ErrorAction SilentlyContinue |
    Out-Null

$cacheFileName = $Repository.Replace('/', '-')
$tagsByDigest |
    ConvertTo-Json |
    Set-Content -Path "$cacheDirectoryPath/$cacheFileName.json"
