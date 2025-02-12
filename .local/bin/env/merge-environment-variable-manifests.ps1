[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string] $Target,

    [Parameter()]
    [string] $GlobalManifest = "$env:XDG_DATA_HOME/env/variables.yaml",

    [Parameter()]
    [string] $LocalManifest = "$env:XDG_DATA_HOME/machine/$($env:COMPUTERNAME.ToLower())/env/variables.yaml"
)

$pathVariableName = 'PATH'
$userScope = 'User'
$machineScope = 'Machine'

class SourceVariable {
    [string[]] $Value
    [string[]] $Issues

    SourceVariable([string[]] $value, [string[]] $issues) {
        $this.Value = $value
        $this.Issues = $issues
    }
}

function Get-UniqueVariableNames {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary[]] $Source,

        [Parameter(Mandatory)]
        [string] $Target
    )
    process {
        $Source |
            ForEach-Object {
                if ($_.Contains($Target)) {
                    $_[$Target].GetEnumerator() |
                        Select-Object -ExpandProperty Name
                }
            } |
            Select-Object -Unique |
            Sort-Object
    }
}

function Get-SourceVariableValue {
    [CmdletBinding()]
    [OutputType([SourceVariable])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Source,

        [Parameter(Mandatory)]
        [string] $SourceName,

        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [string] $VariableName,

        [Parameter()]
        [string[]] $Value
    )
    process {
        $issues = @()

        if ($Source.Contains($Target) -and
            $Source[$Target].Contains($VariableName)) {
            if ($VariableName -eq $pathVariableName) {
                $sourceValue = $Source[$Target][$VariableName]

                if ($Value.Length -eq 0) {
                    $Value += $sourceValue
                } else {
                    $sourceValue |
                        ForEach-Object {
                            if ($Value.Contains($_)) {
                                $issues += "Duplicate $VariableName entry '$_' found in the $SourceName manifest."
                            } else {
                                $Value += $_
                            }
                        }
                }
            }
            else {
                $Value += $Source[$Target][$VariableName]

                if ($Value.Length -gt 1) {
                    $issues += "Found $VariableName in both manifests, the local value will be used."
                    $Value = $Value[1..1]
                }
            }
        }

        [SourceVariable]::new($Value, $issues)
    }
}

function Get-VariableValues {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $MergeSource,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $GlobalSource,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $LocalSource,

        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [string[]] $VariableNames
    )
    process {
        $VariableNames |
            ForEach-Object {
                $variableName = $_
                $variableValue = @()
                $issues = @()

                $getGlobalSourceValueParameters = @{
                    Source = $GlobalSource
                    SourceName = 'global'
                    Target = $Target
                    VariableName = $variableName
                    Value = $variableValue
                }
                $sourceValue = Get-SourceVariableValue @getGlobalSourceValueParameters
                $variableValue = $sourceValue.Value
                $issues += $sourceValue.Issues

                $getLocalSourceValueParameters = @{
                    Source = $LocalSource
                    SourceName = 'local'
                    Target = $Target
                    VariableName = $variableName
                    Value = $variableValue
                }
                $sourceValue = Get-SourceVariableValue @getLocalSourceValueParameters
                $variableValue = $sourceValue.Value
                $issues += $sourceValue.Issues

                $mergeValue = $variableValue
                if ($mergeValue -is [array] -and $mergeValue.Length -eq 1) {
                    $mergeValue = $mergeValue[0]
                }

                $MergeSource[$Target].Add($variableName, $mergeValue)

                $issues
            }
    }
}

$globalSourceObject = Get-Content -Path $GlobalManifest |
    ConvertFrom-Yaml
$localSourceObject = Get-Content -Path $LocalManifest |
    ConvertFrom-Yaml
$sourceObjects = @($globalSourceObject, $localSourceObject)

$newSourceObject = [ordered]@{
    User = [ordered]@{}
    Machine = [ordered]@{}
}
$issues = @()

$userVariableNames = Get-UniqueVariableNames -Source $sourceObjects -Target $userScope
$getUserValuesParameters = @{
    MergeSource = $newSourceObject
    GlobalSource = $globalSourceObject
    LocalSource = $localSourceObject
    Target = 'User'
    VariableNames = $userVariableNames
}
$issues += Get-VariableValues @getUserValuesParameters

$machineVariableNames = Get-UniqueVariableNames -Source $sourceObjects -Target $machineScope
$getMachineValuesParameters = @{
    MergeSource = $newSourceObject
    GlobalSource = $globalSourceObject
    LocalSource = $localSourceObject
    Target = 'Machine'
    VariableNames = $machineVariableNames
}
$issues += Get-VariableValues @getMachineValuesParameters

if ($issues.Length -gt 0) {
    Write-Host 'Manifest Issues:' -ForegroundColor Yellow
    $issues |
        ForEach-Object {
            Write-Host "  $_" -ForegroundColor Yellow
        }

    Write-Host ''
}

$formatManifestScriptPath = "$env:HOME/.local/bin/env/format-environment-variable-manifest.ps1"
$newSourceObject |
    ConvertTo-Yaml |
    & $formatManifestScriptPath |
    Set-Content -Path $Target
