[CmdletBinding()]
param(
    [Parameter()]
    [uri] $Repository
)

if (-not $Repository) {
    $path = & $PSScriptRoot/get-repository-root.ps1 -Path $PWD
    $remoteUri = & git -C $path remote get-url origin 2> $null
    if ($null -eq $remoteUri) {
        throw "The repository '$path' does not have a remote."
    }

    $Repository = [uri]$remoteUri
}

Start-Process -FilePath $Repository
