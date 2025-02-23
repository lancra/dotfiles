[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

$uri = [uri]::new($Id)
if (-not $Id.EndsWith('.git')) {
    $crateId = $uri.Segments[-1]
    & cargo install $crateId
} else {
    $tag = & "$env:HOME/.local/bin/git/get-latest-remote-tag.ps1" -Repository $uri
    & cargo install --git $Id --tag $tag
}
