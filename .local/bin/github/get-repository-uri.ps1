[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter()]
    [string] $Local,

    [Parameter()]
    [string] $Remote
)

function Get-RemoteUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        (& git -C $Path remote get-url origin).TrimEnd('.git')
    }
}

$repositoryUri = ''
if ($Local) {
    $repositoryUri = Get-RemoteUrl -Path $Local
} elseif ($Remote) {
    $repositoryUri = "https://github.com/$Remote"
} else {
    & git rev-parse 2> $null
    if ($LASTEXITCODE -eq 128) {
        throw "No repository provided and working directory is not within a repository."
    }

    $repositoryUri = Get-RemoteUrl -Path $PWD
}

$repositoryUri
