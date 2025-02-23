[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& npm install --location=global $Id
