[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

& cargo install $Id
