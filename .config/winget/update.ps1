[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

& winget upgrade $Id
