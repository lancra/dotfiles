[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id,

    [Parameter()]
    [string] $Local,

    [Parameter()]
    [string] $Remote
)

$repositoryUri = & $PSScriptRoot/get-repository-uri.ps1 -Local $Local -Remote $Remote
$resourceUri = "$repositoryUri/commit/$Id"
Start-Process -FilePath $resourceUri
