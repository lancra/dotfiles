[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

& pip install --upgrade $Id
