[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

& npm update --location=global $Id
