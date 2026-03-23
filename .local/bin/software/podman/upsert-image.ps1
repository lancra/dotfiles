[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& podman pull $Id
