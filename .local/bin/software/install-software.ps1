<#
.SYNOPSIS
Installs software installations as specified in a machine manifest.

.DESCRIPTION
Filters the target software exports by provided values, then retrieves the
identifiers present in the machine manifest and the software installed on the
machine for all matching installations. For all installations present in the
manifest but missing on the machine, the export-specific installation script is
executed.

.PARAMETER Provider
The optional software provider to install. If this parameter is not provided,
all providers are installed.

.PARAMETER DryRun
Specifies to iterate through the software installs without executing them.
#>

using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateScript({
        $_ -in (& "$env:BIN/software/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Provider') {
            $validProviders = (& "$env:BIN/software/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string] $Provider,

    [switch] $DryRun
)

function Get-InstallationIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [string] $Provider
    )
    process {
        Get-Content -Path $Path |
            ConvertFrom-Csv |
            ForEach-Object {
                $exportId = [InstallationExportId]::new($_.Export, $_.Provider)
                if ($Provider -and $_.Provider -ne $Provider) {
                    return
                }

                [InstallationId]::new($_.Id, $exportId)
            }
    }
}

$targetManifestDirectory = & "$env:BIN/env/get-or-add-machine-directory.ps1" -Data
$targetManifestPath = "$targetManifestDirectory/software/installations.csv"
if (-not (Test-Path -Path $targetManifestPath)) {
    throw "The machine manifest was not found at '$targetManifestPath'."
}

$targetIds = Get-InstallationIds -Path $targetManifestPath -Provider $Provider

$exports = & $PSScriptRoot/get-exports.ps1 -Provider $Provider
$currentManifestPath = "$env:TEMP/software.$(Get-Date -Format 'yyyyMMddHHmmss').csv"
& $PSScriptRoot/export-software-manifest.ps1 -Exports $exports -Target $currentManifestPath | Out-Null
$currentIds = Get-InstallationIds -Path $currentManifestPath -Provider $Provider
Remove-Item -Path $currentManifestPath | Out-Null

$installTotal = $targetIds -is [array] ? $targetIds.Length : 1
$installCounter = 1
$targetIds |
    ForEach-Object {
        $targetId = $_
        $currentId = $currentIds |
            Where-Object { $_.Equals($targetId) }

        $exportId = "$($targetId.Provider).$($targetId.Export)"
        if ($currentId) {
            Write-Output "${exportId}: Skipping $($targetId.Value) ($installCounter/$installTotal)."
        } else {
            Write-Output "${exportId}: Installing $($targetId.Value) ($installCounter/$installTotal)."
            $scriptPath = & $PSScriptRoot/get-export-script.ps1 -Id $exportId -Install

            if (-not $DryRun) {
                & $scriptPath -Id $targetId.Value
            }
        }

        $installCounter++
    }
