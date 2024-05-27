[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

& dotnet tool update --global $Id
