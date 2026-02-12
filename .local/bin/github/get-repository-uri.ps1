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
        & git -C $Path remote get-url origin
    }
}

$repositoryUri = ''
if ($Local) {
    $repositoryUri = Get-RemoteUrl -Path $Local
} elseif ($Remote) {
    $repositoryUri = "https://github.com/$Remote"
} else {
    & "$env:BIN/git/check-repository.ps1"
    $repositoryUri = Get-RemoteUrl -Path $PWD
}

$repositoryUri
