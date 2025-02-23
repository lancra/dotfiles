[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& dotnet tool install --global $Id
