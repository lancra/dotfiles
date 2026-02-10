<#
.SYNOPSIS
Unlocks the GPG secret key used for Git.

.DESCRIPTION
Checks for the lock status of the secret key by signing a temporary file. If
executed forcefully, the GPG agent is restarted to lock the key. If the key is
locked at this point, the passphrase (which is sourced from a password manager
or manual input) is used to unlock it and the timestamp is saved in user state
to avoid unnecessary unlock checks until the cache expires.

.PARAMETER SkipPasswordManager
Prompts the user for a passphrase rather than looking it up in a password
manager.

.PARAMETER Force
Restarts the GPG agent, forcing an new key unlock and restarting the cache
expiration.
#>
[CmdletBinding()]
param(
    [switch] $SkipPasswordManager,

    [switch] $Force
)

Get-Command -Name gpg -ErrorAction Stop | Out-Null

if (-not $SkipPasswordManager) {
    Get-Command -Name bw -ErrorAction Stop | Out-Null
}

$filePath = "$env:TEMP/gpg-auth.$(New-Guid).txt"
New-Item -ItemType File -Path $filePath | Out-Null

function Reset-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [switch] $SkipOriginal
    )
    process {
        Write-Verbose 'Deleting temporary files.'
        if (-not $SkipOriginal) {
            Remove-Item -Path $Path | Out-Null
        }

        Remove-Item -Path "$Path.gpg" | Out-Null
    }
}

function Connect-Bitwarden {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    process {
        Write-Verbose 'Checking authentication status for Bitwarden.'
        $status = & bw login --check 2>&1
        $authenticated = $status -eq 'You are logged in!'

        if ($authenticated) {
            Write-Verbose 'Unlocking Bitwarden.'
            $message = & bw unlock
        } else {
            Write-Verbose 'Authenticating Bitwarden.'
            $message = & bw login
        }

        $sessionLine = $message |
            Where-Object { $_.StartsWith('>') } |
            Select-Object -First 1

        $sessionGroup = 'session'
        $sessionLine |
            Select-String -Pattern "`"(?<$sessionGroup>.*?)`"" |
            Select-Object -ExpandProperty Matches |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $sessionGroup |
            Select-Object -ExpandProperty Value
    }
}

function Test-Gpg {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        Write-Verbose 'Checking GPG for cached passphrase.'
        $result = & gpg --pinentry-mode error --sign $Path 2>&1
        return $null -eq $result
    }
}

function Connect-Gpg {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [securestring] $Passphrase,

        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        Write-Verbose 'Caching passphrase with GPG.'
        $rawPasphrase = $Passphrase | ConvertFrom-SecureString -AsPlainText
        & gpg --pinentry-mode loopback --passphrase $rawPasphrase --sign $Path

        & "$env:BIN/record-gpg-auth.ps1"
    }
}

$cached = Test-Gpg -Path $filePath
Write-Verbose "Found$(-not $cached ? ' no': '') cached passphrase."
if ($cached -and $Force) {
    Reset-File -Path $filePath -SkipOriginal

    Write-Verbose 'Reloading agent to force a re-cache.'
    & gpg-connect-agent.exe reloadagent /bye 2>&1> $null
    $cached = $false
}

if (-not $cached) {
    if ($SkipPasswordManager) {
        $passphrase = Read-Host -Prompt 'Passphrase' -AsSecureString
    } else {
        $bitwardenSession = Connect-Bitwarden

        Write-Verbose 'Getting secret key passphrase from Bitwarden.'
        $passphrase = & bw get --session $bitwardenSession password gpg |
            ConvertTo-SecureString -AsPlainText

        & bw lock | Out-Null
    }

    Connect-Gpg -Passphrase $passphrase -Path $filePath
}

Reset-File -Path $filePath
