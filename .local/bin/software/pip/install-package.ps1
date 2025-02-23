[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& python -m pip install $Id
