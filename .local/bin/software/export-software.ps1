#Requires -Modules powershell-yaml

<#
.SYNOPSIS
Exports software installation state for global and machine-specific states.

.DESCRIPTION
Filters the target software exports by provided values, then executes a manifest
export for all matching installations. Then, iterating through each export, the
unique installations from all machine manifests are used to determine the
installation population for each definition collection. Finally, the environment
variables are exported to their respective manifests.

.PARAMETER Provider
The optional software provider to export. If this parameter is not provided, all
providers are exported.

.PARAMETER Export
The optional software provider export to export. If this parameter is not
provided, all provider exports are exported.
#>

using module ./software.psm1

[CmdletBinding(DefaultParameterSetName = 'Provider')]
param (
    [Parameter(ParameterSetName = 'Provider', Position = 0)]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Provider') {
            $validProviders = (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string[]] $Provider,

    [Parameter(ParameterSetName = 'Export')]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-export-ids.ps1")},
        ErrorMessage = 'Export not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Export') {
            $validExports = (& "$env:HOME/.local/bin/software/get-export-ids.ps1")
            $validExports -like "$wordToComplete*"
        }
    })]
    [string[]] $Export
)
begin {
    & "$env:HOME/.local/bin/env/begin-loading.ps1"

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
                Get-ChildItem -Path "$env:XDG_DATA_HOME/machine/*/software" -Filter 'installations.csv' -Depth 1 |
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
            [InstallationId[]] $Ids,

            [Parameter()]
            [PSObject[]] $Definitions
        )
        process {
            $definitionDirectory = Get-DefinitionDirectory -Export $Export
            $definitionPath = "$definitionDirectory/$($Export.Id.ToString()).yaml"

            $persistedDefinitions = @()
            if (Test-Path -Path $definitionPath) {
                $persistedDefinitions = (Get-Content -Path $definitionPath |
                    ConvertFrom-Yaml -Ordered).GetEnumerator() |
                    ForEach-Object {
                        New-Object -TypeName PSObject -Property $_
                    }
            }

            $Ids |
                Select-Object -ExpandProperty Value |
                ForEach-Object {
                    $definition = $Definitions |
                        Where-Object -Property Id -EQ $_
                    $persistedDefinition = $persistedDefinitions |
                        Where-Object -Property Id -EQ $_

                    if ($definition) {
                        $definition
                    } elseif ($persistedDefinition) {
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
    $inMemoryInstallations = & $PSScriptRoot/export-software-manifest.ps1 -Exports $exports

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

            Export-Definitions -Export $_ -Ids $targetInstallationIds -Definitions $definitions
        }

    & "$env:HOME/.local/bin/env/export-variables.ps1"
}
end {
    & "$env:HOME/.local/bin/env/end-loading.ps1"
}
