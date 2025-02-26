[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

Update-Module -Name $Id -Scope CurrentUser
