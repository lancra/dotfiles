using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Provider')]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Provider') {
            $validProviders = (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")
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

$targetManifestDirectory = & "$env:HOME/.local/bin/env/get-or-add-machine-directory.ps1" -Data
$targetManifestPath = "$targetManifestDirectory/software.csv"
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
            Write-Output "${exportId}: Skipping $($_.Value) ($installCounter/$installTotal)."
        } else {
            Write-Output "${exportId}: Installing $($_.Value) ($installCounter/$installTotal)."
            $scriptPath = & $PSScriptRoot/get-export-script.ps1 -Id $exportId -Install

            if (-not $DryRun) {
                & $scriptPath -Id $_.Id.Value
            }
        }

        $installCounter++
    }
