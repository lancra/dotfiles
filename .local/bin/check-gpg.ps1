<#
.SYNOPSIS
Checks the unlock status of the GPG key used for Git.

.DESCRIPTION
Finds the GPG authentication state file and reads the contained timestamp. If
the file is not found, authentication is deemed missing. If the timestamp is in
the past, authentication is deemed expired. Otherwise, the expiration time is
provided.
#>
[CmdletBinding()]
param()

function Get-GpgConfiguration {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Key
    )
    process {
        Get-Content -Path "$env:HOME/.gnupg/gpg-agent.conf" |
            ForEach-Object {
                $entry = $_.Split(' ')
                if ($entry[0] -eq $Key) {
                    return $entry[1]
                }
            }
    }
}

$authStatePath = "$env:XDG_STATE_HOME/gpg/auth"
if (-not (Test-Path -Path $authStatePath)) {
    Write-Host "GPG is not authenticated." -ForegroundColor Red
}

$authDateText = Get-Content -Path $authStatePath
$authDate = [datetime]::Parse($authDateText)

$maxCacheTimeToLiveSecondsText = Get-GpgConfiguration -Key 'max-cache-ttl'
$maxCacheTimeToLive = [timespan]::FromSeconds([int]::Parse($maxCacheTimeToLiveSecondsText))
$authExpirationDate = $authDate + $maxCacheTimeToLive
$currentDate = Get-Date
if ($currentDate -gt $authExpirationDate) {
    Write-Host "GPG authentication has expired." -ForegroundColor Red
} else {
    Write-host "GPG authentication expires at $($authExpirationDate.ToString('s'))." -ForegroundColor Green
}
