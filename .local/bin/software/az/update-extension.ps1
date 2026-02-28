[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& az extension update --name $Id
