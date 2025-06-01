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
