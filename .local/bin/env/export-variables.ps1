#Requires -Modules powershell-yaml

[CmdletBinding()]
param (
    [Parameter()]
    [string] $GlobalTarget = "$env:XDG_DATA_HOME/env/variables.yaml",

    [Parameter()]
    [string] $LocalTarget = "$env:XDG_DATA_HOME/machine/$($env:COMPUTERNAME.ToLower())/env/variables.yaml"
)

$prefixVariableNames = @(
    'LOCALAPPDATA',
    'APPDATA',
    'USERPROFILE',
    'DEVUSERPROFILE',
    'HOME',
    'DEV_HOME',
    'SYSTEMROOT',
    'PROGRAMFILES(X86)',
    'PROGRAMFILES'
)

$prefixVariables = [ordered]@{}
$prefixVariableNames |
    ForEach-Object {
        $prefixVariables[$_] = [System.Environment]::GetEnvironmentVariable($_)
    }

function Set-PathPrefix {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary] $Prefixes,

        [Parameter()]
        [string] $Path,

        [switch] $AllowExact
    )
    begin {
        $pathRegex = '[a-zA-Z]:[\\\/]'
    }
    process {
        if ($Path -notmatch $pathRegex) {
            Write-Verbose "$Path does not match the format for path prefixing."
            return $Path
        }

        foreach ($prefix in $Prefixes.GetEnumerator()) {
            $prefixPath = $prefix.Value
            Write-Verbose "  Testing Path=$Path, Prefx=$prefixPath"

            if ($Path -like "$prefixPath*" -and ($Path -ne $prefixPath -or $AllowExact)) {
                $prefixName = $prefix.Key
                $pathSuffix = $Path.Substring($prefixPath.Length)
                $resultPath = "%$prefixName%$pathSuffix"

                Write-Verbose "    Match=$resultPath"
                return $resultPath
            }
        }

        $Path
    }
}

function Get-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([ordered])]
    param (
        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [string[]] $IgnoredSubkeys
    )
    begin {
        $registryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    }
    process {
        $environmentVariables = [ordered]@{}
        $registryKey = Get-Item -Path $Key
        $registryKey |
            Select-Object -ExpandProperty Property |
            Sort-Object |
            ForEach-Object {
                $key = $_.ToUpper()
                if ($IgnoredSubkeys -contains $key) {
                    return
                }

                $value = $registryKey.GetValue($_, '', $registryValueOptions)
                if ($key -eq 'PATH') {
                    Write-Verbose 'Processing PATH variable parts...'
                    $valueParts = $value -split ';' -ne ''
                    $prefixedParts = @()

                    foreach ($part in $valueParts) {
                        Write-Verbose "Processing $part from PATH..."
                        $prefixedParts += Set-PathPrefix -Prefixes $prefixVariables -Path $part -AllowExact
                    }

                    $value = $prefixedParts
                } else {
                    Write-Verbose "Processing $key variable..."
                    $value = Set-PathPrefix -Prefixes $prefixVariables -Path $value
                }

                $environmentVariables[$key] = $value
            }

        $environmentVariables
    }
}

$sourceVariables = [ordered]@{}

$builtInUserVariables = @(
    'TEMP',
    'TMP'
)

$ignoredUserVariables = $builtInUserVariables
$ignoredUserVariablesPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'env' -AdditionalChildPath '.ignored-user-variables.json'
if (Test-Path -Path $ignoredUserVariablesPath) {
    @(Get-Content -Path $ignoredUserVariablesPath | ConvertFrom-Json) |
        ForEach-Object { $ignoredUserVariables += $_ }
}

$getUserVariablesArgs = @{
    Key = 'HKCU:\Environment'
    IgnoredSubkeys = $ignoredUserVariables
}
$sourceVariables['User'] = Get-EnvironmentVariable @getUserVariablesArgs

$builtInMachineVariables = @(
    'COMSPEC',
    'CONFIGSETROOT',
    'DRIVERDATA',
    'NUMBER_OF_PROCESSORS',
    'OS',
    'PATHEXT',
    'POWERSHELL_DISTRIBUTION_CHANNEL',
    'PROCESSOR_ARCHITECTURE',
    'PROCESSOR_IDENTIFIER',
    'PROCESSOR_LEVEL',
    'PROCESSOR_REVISION',
    'PSMODULEPATH',
    'TEMP',
    'TMP',
    'USERNAME',
    'WINDIR'
)
$getMachineVariablesArgs = @{
    Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    IgnoredSubkeys = $builtInMachineVariables
}
$sourceVariables['Machine'] = Get-EnvironmentVariable @getMachineVariablesArgs

$sourceLocalVariables = [ordered]@{
    User = [ordered]@{}
    Machine = [ordered]@{}
}

$sourceGlobalVariables = [ordered]@{
    User = [ordered]@{}
    Machine = [ordered]@{}
}
$targetGlobalVariables = @{}
if (Test-Path -Path $GlobalTarget) {
    $targetGlobalVariables = Get-Content -Path $GlobalTarget |
        ConvertFrom-Yaml
}

$sourceVariables.GetEnumerator() |
    ForEach-Object {
        $variableTarget = $_.Name

        $_.Value.GetEnumerator() |
            ForEach-Object {
                $variableName = $_.Name
                $variableValue = $_.Value

                $targetContainsVariableTarget = $targetGlobalVariables.Contains($variableTarget)
                $targetContainsVariableName = $targetContainsVariableTarget -and
                    $targetGlobalVariables[$variableTarget].Contains($variableName)

                $isPath = $variableName -eq 'PATH'
                $isGlobal = $targetContainsVariableName -and -not $isPath

                if (-not $isPath) {
                    $modifiedSource = $isGlobal ? $sourceGlobalVariables : $sourceLocalVariables
                    $modifiedSource[$variableTarget].Add($variableName, ([string]$variableValue))
                } else {
                    $variableValue |
                        ForEach-Object {
                            $isGlobal = $targetContainsVariableName -and
                                $targetGlobalVariables[$variableTarget][$variableName].Contains($_)
                            $modifiedSource = $isGlobal ? $sourceGlobalVariables : $sourceLocalVariables

                            if (-not $modifiedSource[$variableTarget].Contains($variableName)) {
                                $modifiedSource[$variableTarget].Add($variableName, @())
                            }

                            $modifiedSource[$variableTarget][$variableName] += ([string]$_)
                        }
                }
            }
    }

function Write-Source {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Source
    )
    process {
        $Source.GetEnumerator() |
        ForEach-Object {
            $variableTarget = $_.Name
            $_.Value.GetEnumerator() |
                ForEach-Object {
                    if (-not ($_.Value -is [array])) {
                        Write-Host "${variableTarget}: $($_.Name) = $($_.Value)"
                    } else {
                        Write-Host "${variableTarget}: $($_.Name) ="
                        $_.Value |
                            ForEach-Object {
                                Write-Host "  - $_"
                            }
                    }
                }
        }
    }
}

$formatManifestScriptPath = "$env:HOME/.local/bin/env/format-environment-variable-manifest.ps1"
$sourceGlobalVariables |
    ConvertTo-Yaml |
    & $formatManifestScriptPath |
    Set-Content -Path $GlobalTarget

$sourceLocalVariables |
    ConvertTo-Yaml |
    & $formatManifestScriptPath |
    Set-Content -Path $LocalTarget
