[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Registry,

    [Parameter(Mandatory)]
    [string] $Repository
)

function New-CurlCommand {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [string] $Url,

        [Parameter()]
        [string] $Token,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $Option
    )
    process {
        $arguments = @(
            'curl',
            '--silent'
        )

        if (-not [string]::IsNullOrEmpty($Token)) {
            $arguments += "--header 'Authorization: Bearer $Token'"
        }

        $arguments += $Option
        $arguments += $Url

        return [scriptblock]::Create("$arguments")
    }
}

function Get-RepositoryTagDigest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Url,

        [Parameter()]
        [string] $Token
    )
    process {
        $getDockerManifestCommandArguments = @{
            Url = $Url
            Token = $Token
            Option = @(
                "--header 'Accept: application/vnd.docker.distribution.manifest.v2+json'",
                "--write-out '{`"metadata`":%{json},`"headers`":%{header_json}}'",
                "--out-null"
            )
        }

        $getDockerManifestCommand = New-CurlCommand @getDockerManifestCommandArguments
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
        $getOciImageIndexCommandArguments = @{
            Url = $Url
            Token = $Token
            Option = @(
                "--header 'Accept: application/vnd.oci.image.index.v1+json'",
                "--output '$responsePath'"
            )
        }

        $getOciImageIndexCommand = New-CurlCommand @getOciImageIndexCommandArguments
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

$newCurlCommandFunction = ${function:New-CurlCommand}.ToString()
$getRepositoryTagDigestFunction = ${function:Get-RepositoryTagDigest}.ToString()

$tagsByDigest = @{}
$tagProperties = @(
    @{ Name = 'Tag'; Expression = { $_ } },
    @{ Name = 'Url'; Expression = { "https://$Registry/v2/$Repository/manifests/$_" } }
)

$registryDefinition = & "$PSScriptRoot/get-registry-definitions.ps1" -Uri $Registry
$token = $null
if ($registryDefinition.Authentication) {
    $token = & "$PSScriptRoot/get-$($registryDefinition.ScriptName)-token.ps1" -Repository $Repository
}

$getTagsCommand = New-CurlCommand -Url "https://$Registry/v2/$Repository/tags/list" -Token $token
Invoke-Command -ScriptBlock $getTagsCommand |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'tags' |
    Select-Object -Property $tagProperties |
    ForEach-Object -Parallel {
        ${function:New-CurlCommand} = $using:newCurlCommandFunction
        ${function:Get-RepositoryTagDigest} = $using:getRepositoryTagDigestFunction

        $digest = Get-RepositoryTagDigest -Url $_.Url -Token $using:token

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

$cacheDirectoryPath = "$env:XDG_CACHE_HOME/image-digests/$Registry"
New-Item -ItemType Directory -Path $cacheDirectoryPath -ErrorAction SilentlyContinue |
    Out-Null

$cacheFileName = $Repository.Replace('/', '-')
$tagsByDigest |
    ConvertTo-Json |
    Set-Content -Path "$cacheDirectoryPath/$cacheFileName.json"
