using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [InstallationExport[]] $Exports,

    [Parameter()]
    [string] $Target
)

$inMemoryInstallations = $Exports |
    ForEach-Object {
        & $PSScriptRoot/get-export-script.ps1 -Id $_.Id.ToString() -Export
    } |
    ForEach-Object -Parallel {
        & $_
    } |
    Sort-Object -Property @(
        @{ Expression = { $_.Id.Provider } },
        @{ Expression = { $_.Id.Export } },
        @{ Expression = { $_.Id.Value } }
    )

$persistedInstallations = @()
$machineManifestDirectory = & "$env:HOME/.local/bin/env/get-or-add-machine-directory.ps1" -Data
$machineManifestPath = "$machineManifestDirectory/software/installations.csv"
if (Test-Path -Path $machineManifestPath) {
    $persistedInstallations = Get-Content -Path $machineManifestPath |
        ConvertFrom-Csv
}

$Exports |
    ForEach-Object {
        $targetExport = $_

        $persistedInstallations = $persistedInstallations |
            Where-Object { $_.Provider -ne $targetExport.Id.Provider -or $_.Export -ne $targetExport.Id.Export }

        $persistedInstallations += $inMemoryInstallations |
            Select-Object -Property @(
                @{ Name = 'Provider'; Expression = { $_.Id.Provider }},
                @{ Name = 'Export'; Expression = { $_.Id.Export }},
                @{ Name = 'Id'; Expression = { $_.Id.Value }}
            ) |
            Where-Object {
                $targetExport.Scope -eq [InstallationExportScope]::Global -and
                $_.Provider -eq $targetExport.Id.Provider -and
                $_.Export -eq $targetExport.Id.Export
            }
    }

$manifestExportPath = $Target ? $Target : $machineManifestPath
$persistedInstallations |
    Sort-Object -Property @('Provider', 'Export', 'Id') |
    Export-Csv -Path $manifestExportPath -UseQuotes AsNeeded

return $inMemoryInstallations
