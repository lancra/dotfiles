<#
.SYNOPSIS
Opens online help documents for an application command in the default browser.

.DESCRIPTION
Parses the configuration of online help applications to determine the base URL
for individual commands. The command is then appended to construct the help URL
and the default browser is started at the URL.

.PARAMETER Application
The application to open online help for.

.PARAMETER Command
The command to open online help for.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Application,

    [Parameter(Mandatory)]
    [string] $Command
)

$applications = Get-Content -Path "$env:XDG_CONFIG_HOME/online-help.json" |
    ConvertFrom-Json

$applicationFormat = $applications.$Application
if ($null -eq $applicationFormat) {
    throw "Unable to open help for unknown application $Application."
}

$applicationUri = $applicationFormat -f $Command
Start-Process -FilePath $applicationUri
