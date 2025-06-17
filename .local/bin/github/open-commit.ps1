<#
.SYNOPSIS
Opens a browser tab for a Git commit on the remote GitHub repository.

.DESCRIPTION
Retrieves the GitHub repository URI from provided specifications, either a
partial GitHub URI or a local filesystem path. When neither are provided, the
working directory is used. The URI is then combined with the commit SHA and
opened in the default browser.

.PARAMETER Id
The SHA identifier of the commit to open.

.PARAMETER Local
The local filesystem path for the Git repository.

.PARAMETER Remote
The organization and repository identifier for the GitHub repository.
#>
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
