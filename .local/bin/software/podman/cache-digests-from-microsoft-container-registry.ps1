[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Repository
)

$tagsByDigest = @{}
$tagProperties = @(
    @{ Name = 'Tag'; Expression = { $_} },
    @{ Name = 'Url'; Expression = { "https://mcr.microsoft.com/v2/$Repository/manifests/$_"} }
)
& curl --silent "https://mcr.microsoft.com/v2/$Repository/tags/list" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'tags' |
    Select-Object -Property $tagProperties |
    ForEach-Object -Parallel {
        $digestCommandArguments = @(
            'curl',
            '--silent',
            "--header 'Accept: application/vnd.docker.distribution.manifest.v2+json'",
            "--write-out '%header{Docker-Content-Digest}'",
            "--out-null",
            $_.Url
        )
        $digestCommand = [scriptblock]::Create("$digestCommandArguments")
        $digest = Invoke-Command -ScriptBlock $digestCommand

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
