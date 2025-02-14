[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

if (-not $Id.EndsWith('.git')) {
    $crateId = [Uri]::new($Id).Segments[-1]
    & cargo install $crateId
}
