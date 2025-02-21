#Requires -Modules powershell-yaml
using module ./software.psm1

[CmdletBinding(DefaultParameterSetName = 'Provider')]
param (
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

    [Parameter(ParameterSetName = 'Export')]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-export-ids.ps1")},
        ErrorMessage = 'Export not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Export') {
            $validExports = (& "$env:HOME/.local/bin/software/get-export-ids.ps1")
            $validExports -like "$wordToComplete*"
        }
    })]
    [string] $Export
)
begin {
    & "$env:HOME/.local/bin/env/begin-loading.ps1"

    function Export-MachineManifest {
        [CmdletBinding()]
        [OutputType([Installation[]])]
        param(
            [Parameter(Mandatory)]
            [InstallationExport[]] $Exports
        )
        process {
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
            $machineManifestPath = "$machineManifestDirectory/software.csv"
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

            $persistedInstallations |
                Sort-Object -Property @('Provider', 'Export', 'Id') |
                Export-Csv -Path $machineManifestPath -UseQuotes AsNeeded

            return $inMemoryInstallations
        }
    }

    function Get-UniqueInstallationIdentifiers {
        [CmdletBinding()]
        [OutputType([InstallationId[]])]
        param(
            [Parameter(Mandatory)]
            [InstallationExport] $Export,

            [Parameter(Mandatory)]
            [Installation[]] $InMemoryInstallations
        )
        process {
            if ($Export.Scope -eq [InstallationExportScope]::Global) {
                Get-ChildItem -Path "$env:XDG_DATA_HOME/machine" -Filter 'software.csv' -Depth 1 |
                    ForEach-Object {
                        Get-Content -Path $_ |
                            ConvertFrom-Csv |
                            ForEach-Object {
                                $exportId = [InstallationExportId]::new($_.Export, $_.Provider)
                                [InstallationId]::new($_.Id, $exportId)
                            }
                    } |
                    Where-Object { $_.Provider -eq $Export.Id.Provider -and $_.Export -eq $Export.Id.Export } |
                    Sort-Object -Property @{ Expression = { $_.ToString() } } -Unique
            } else {
                $InMemoryInstallations |
                    Where-Object { $_.Id.Provider -eq $Export.Id.Provider -and $_.Id.Export -eq $Export.Id.Export } |
                    ForEach-Object {
                        # Using Select-Object for the Id property results in object reference exceptions on equality comparison, so
                        # this must instead redefine the property as a new class instance.
                        [InstallationId]::new($_.Id.Value, [InstallationExportId]::new($_.Id.Export, $_.Id.Provider))
                    }
            }
        }
    }

    function Get-DefinitionDirectory {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory)]
            [InstallationExport] $Export
        )
        process {
            if ($Export.Scope -eq [InstallationExportScope]::Global) {
                $manifestGlobalDirectory = "$env:XDG_DATA_HOME/software"
                New-Item -ItemType Directory -Path $manifestGlobalDirectory -Force | Out-Null
                $manifestGlobalDirectory
            } else {
                $machineDataDirectory = & $env:HOME/.local/bin/env/get-or-add-machine-directory.ps1 -Data
                $manifestLocalDirectory = "$machineDataDirectory/software"
                New-Item -ItemType Directory -Path $manifestLocalDirectory -Force | Out-Null
                $manifestLocalDirectory
            }
        }
    }

    function Export-Definitions {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [InstallationExport] $Export,

            [Parameter(Mandatory)]
            [PSObject[]] $Definitions
        )
        process {
            $definitionDirectory = Get-DefinitionDirectory -Export $Export
            $definitionPath = "$definitionDirectory/$($Export.Id.ToString()).yaml"

            $persistedDefinitions = @()
            if (Test-Path -Path $definitionPath) {
                $persistedDefinitions = Get-Content -Path $definitionPath |
                    ConvertFrom-Yaml
            }

            $targetInstallationIds |
                Select-Object -ExpandProperty Value |
                ForEach-Object {
                    $definition = $Definitions |
                        Where-Object -Property Id -EQ $_
                    $persistedDefinition = $persistedDefinitions |
                        Where-Object -Property Id -EQ $_

                    if ($definition) {
                        $definition
                    } elseif ($persistedInstallation) {
                        $persistedDefinition
                    }
                } |
                ConvertTo-Yaml |
                & yq --input-format 'yaml' --prettyPrint |
                Set-Content -Path $definitionPath
        }
    }
}
process {
    $exports = & $PSScriptRoot/get-exports.ps1 -Provider $Provider -Export $Export

    $inMemoryInstallations = Export-MachineManifest -Exports $exports

    $exports |
        ForEach-Object {
            $getUniqueInstallationIdentifiersParameters = @{
                Export = $_
                InMemoryInstallations = $inMemoryInstallations
            }
            $targetInstallationIds = Get-UniqueInstallationIdentifiers @getUniqueInstallationIdentifiersParameters

            $definitions = $inMemoryInstallations |
                Where-Object { $targetInstallationIds -contains $_.Id } |
                ForEach-Object {
                    $properties = [ordered]@{
                        Id = $_.Id.Value
                    }

                    $_.Metadata.GetEnumerator() |
                        ForEach-Object {
                            $value = $_.Value
                            if ($_.Value -is [array]) {
                                $value = $_.Value |
                                    ForEach-Object {
                                        $_.ToString()
                                    }
                            }

                            $properties[$_.Key] = $value
                        }

                    New-Object -Type PSObject -Property $properties
                }

            Export-Definitions -Export $_ -Definitions $definitions
        }

    & "$env:HOME/.local/bin/env/export-variables.ps1"
}
end {
    & "$env:HOME/.local/bin/env/end-loading.ps1"
}
