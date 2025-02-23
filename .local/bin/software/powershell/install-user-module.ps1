[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

Install-Module -Name $Id
