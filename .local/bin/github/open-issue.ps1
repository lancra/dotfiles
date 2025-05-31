[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [int] $Id,

    [Parameter()]
    [string] $Local,

    [Parameter()]
    [string] $Remote
)

$repositoryUri = & $PSScriptRoot/get-repository-uri.ps1 -Local $Local -Remote $Remote
$resourceUri = "$repositoryUri/issues/$Id"
Start-Process -FilePath $resourceUri
