<#
.SYNOPSIS
Records the authentication date for GPG.

.DESCRIPTION
Saves the current timestamp in user state to avoid unnecessary unlock checks
until the cache expires.
#>
[CmdletBinding()]
param()

$sortableIso8601Format = 's'
$authDate = Get-Date -Format $sortableIso8601Format

$gpgStateDirectory = "$env:XDG_STATE_HOME/gpg"
New-Item -ItemType Directory -Path $gpgStateDirectory -Force | Out-Null

$gpgAuthStatePath = "$gpgStateDirectory/auth"
Set-Content -Path $gpgAuthStatePath -Value $authDate
