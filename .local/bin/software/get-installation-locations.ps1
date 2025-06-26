<#
.SYNOPSIS
Retrieves the full list of installations with the machines they're present on.

.DESCRIPTION
For the specified software providers, the unique installations are pulled from
the machine manifests and stored in a central lookup, along with the source for
each pull.

.PARAMETER Provider
The optional software provider to query. If this parameter is not provided, all
providers are queried.

.PARAMETER Export
The optional software provider export to query. If this parameter is not
provided, all provider exports are queried.
#>

using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter()]
    [string[]] $Provider,

    [Parameter()]
    [string[]] $Export
)

$installations = @{}

$exports = & $PSScriptRoot/get-exports.ps1 -Provider $Provider -Export $Export
$exports |
    ForEach-Object {
        $exportId = $_.Id
        & $PSScriptRoot/get-installation-definitions.ps1 -Export $exportId |
            Select-Object -ExpandProperty Id |
            ForEach-Object {
                $id = [InstallationId]::new($_, $exportId)
                $installations[$id] = @()
            }
    }

& $env:HOME/.local/bin/env/get-machines.ps1 |
    ForEach-Object {
        $machine = $_
        Get-Content -Path "$env:XDG_DATA_HOME/machine/$_/software/installations.csv" |
            ConvertFrom-Csv |
            ForEach-Object {
                $exportId = [InstallationExportId]::new($_.Export, $_.Provider)
                $includeExport = ($exports |
                    Where-Object { $_.Id.ToString() -eq $exportId.ToString() } |
                    Measure-Object |
                    Select-Object -ExpandProperty Count) -ne 0
                if (-not $includeExport) {
                    return
                }

                $id = [InstallationId]::new($_.Id, $exportId)
                $installations[$id] += $machine
            }
    }

$installations.GetEnumerator() |
    Sort-Object -Property Key |
    ForEach-Object {
        [InstallationLocation]::new($_.Key, $_.Value)
    }
