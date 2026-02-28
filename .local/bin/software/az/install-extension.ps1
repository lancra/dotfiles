[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& az extension add --name $Id
