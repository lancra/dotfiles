[CmdletBinding()]
param (
    [Parameter()]
    [string] $Source = "$env:XDG_DATA_HOME/env/variables.yaml"
)

# Represents the comparison result for a single environment variable target.
class TargetComparisonResult {
    [System.EnvironmentVariableTarget] $Target
    [string[]] $Variables

    TargetComparisonResult([System.EnvironmentVariableTarget] $target, [string[]] $variables) {
        $this.Target = $target
        $this.Variables = $variables
    }
}

# Represents the comparison result across all environment variable targets.
class ComparisonResult {
    [bool] $HasDifferences
    [TargetComparisonResult[]] $TargetResults

    ComparisonResult([bool] $hasDifferences, [TargetComparisonResult[]] $targetResults) {
        $this.HasDifferences = $hasDifferences
        $this.TargetResults = $targetResults
    }
}

# Represents the descriptor for an environment variable import operation.
class ImportDescriptor {
    [bool] $Valid
    [string] $Symbol
    [System.ConsoleColor] $Color

    ImportDescriptor([bool] $valid, [string] $symbol, [System.ConsoleColor] $color) {
        $this.Valid = $valid
        $this.Symbol = $symbol
        $this.Color = $color
    }
}

function Compare-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([ComparisonResult])]
    param (
        [Parameter(Mandatory)]
        [string]$Source
    )
    begin {
        function New-ComparisonResult {
            [CmdletBinding()]
            [OutputType([ComparisonResult])]
            param(
                [Parameter(Mandatory)]
                [bool] $HasDifferences,
                [Parameter(Mandatory)]
                [string] $SourcePath,
                [Parameter(Mandatory)]
                [string] $TargetPath
            )
            begin {
                function Select-Variables {
                    [CmdletBinding()]
                    [OutputType([string[]])]
                    param(
                        [Parameter(Mandatory)]
                        [string] $Path,
                        [Parameter(Mandatory)]
                        [string] $Target
                    )
                    process {
                        Get-Content -Path $Path |
                            ConvertFrom-Yaml |
                            Select-Object -ExpandProperty $Target |
                            Select-Object -ExpandProperty Keys
                    }
                }
            }
            process {
                $userTarget = 'User'
                $sourceUserVariables = Select-Variables -Path $SourcePath -Target $userTarget
                $targetUserVariables = Select-Variables -Path $TargetPath -Target $userTarget
                $userVariables = ($sourceUserVariables + $targetUserVariables) |
                    Select-Object -Unique |
                    Sort-Object
                $userComparisonResult = [TargetComparisonResult]::new([System.EnvironmentVariableTarget]$userTarget, $userVariables)

                $machineTarget = 'Machine'
                $sourceMachineVariables = Select-Variables -Path $SourcePath -Target $machineTarget
                $targetMachineVariables = Select-Variables -Path $TargetPath -Target $machineTarget
                $machineVariables = ($sourceMachineVariables + $targetMachineVariables) |
                    Select-Object -Unique |
                    Sort-Object
                $machineComparisonResult = [TargetComparisonResult]::new(
                    [System.EnvironmentVariableTarget]$machineTarget,
                    $machineVariables)

                [ComparisonResult]::new($HasDifferences, @($userComparisonResult, $machineComparisonResult))
            }
        }
    }
    process {
        Write-Host 'Comparing configured environment variables with the registry.'

        $targetDirectory = "$env:TEMP/$(New-Guid)"
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

        $targetPath = "$targetDirectory/environment-variables.yaml"
        & "$env:HOME/.local/bin/env/export-variables.ps1" -Target $targetPath

        # Use UTF-8 so that Tee-Object doesn't garble Unicode symbols.
        $originalEncoding = [System.Console]::OutputEncoding
        [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        dyff --color on between --omit-header --set-exit-code $targetPath $Source |
            Tee-Object -Variable differences |
            Write-Host
        $hasDifferences = $LASTEXITCODE -ne 0

        [System.Console]::OutputEncoding = $originalEncoding

        $comparisonResult = New-ComparisonResult -HasDifferences $hasDifferences -SourcePath $Source -TargetPath $targetPath

        Remove-Item -Path $targetDirectory -Recurse | Out-Null

        $comparisonResult
    }
}

$comparisonResult = Compare-EnvironmentVariable -Source $Source
if (-not $comparisonResult.HasDifferences) {
    Write-Output 'No changes detected.'
    exit 0
}

$continueInput = 'y'
$cancelInput = 'N'
$validInputs = @($continueInput, $cancelInput)

$script:input = ''
do {
    $script:input = Read-Host -Prompt "Continue with import? ($continueInput/$cancelInput)"
} while ($script:input -and -not ($validInputs -like $script:input))

if (-not $script:input.Equals($continueInput, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output 'Canceled import.'
    exit 0
}

$sourceObject = Get-Content -Path $Source | ConvertFrom-Yaml

$windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
$runningAsAdministrator = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Output ''

$updatedImportDescriptor = [ImportDescriptor]::new($true, '~', [System.ConsoleColor]::Yellow)
$removedImportDescriptor = [ImportDescriptor]::new($true, '-', [System.ConsoleColor]::Red)
$addedImportDescriptor = [ImportDescriptor]::new($true, '+', [System.ConsoleColor]::Green)
$failedImportDescriptor = [ImportDescriptor]::new($false, 'X', [System.ConsoleColor]::Magenta)

$comparisonResult.TargetResults |
    ForEach-Object {
        $target = $_.Target
        $targetName = $target.ToString()
        $_.Variables |
            ForEach-Object {
                $variable = $_
                $sourceValue = $sourceObject.$targetName.$variable
                if ($sourceValue -is [System.Collections.Generic.List[object]]) {
                    $sourceValue = ($sourceValue -join ';') + ';'
                }

                $sourceValueExpanded = [System.Environment]::ExpandEnvironmentVariables($sourceValue)
                $targetValue = [System.Environment]::GetEnvironmentVariable($variable, $target)

                $valuesEqual = $sourceValueExpanded -eq $targetValue
                if ($valuesEqual) {
                    return
                }

                $importDescriptor = $updatedImportDescriptor
                if (-not $sourceValueExpanded) {
                    $importDescriptor = $removedImportDescriptor
                } elseif ($null -eq $targetValue) {
                    $importDescriptor = $addedImportDescriptor
                }

                $failureContext = ''
                if ($target -eq [System.EnvironmentVariableTarget]::Machine -and -not $runningAsAdministrator) {
                    $importDescriptor = $failedImportDescriptor
                    $failureContext = ' (Failed to import, re-execute as an administrator.)'
                }

                if ($importDescriptor.Valid) {
                    [System.Environment]::SetEnvironmentVariable($variable, $sourceValueExpanded, $target) | Out-Null
                }

                $defaultTextColor = [System.Console]::ForegroundColor
                [System.Console]::ForegroundColor = $importDescriptor.Color
                Write-Output "$($importDescriptor.Symbol) $targetName.$variable$failureContext"
                [System.Console]::ForegroundColor = $defaultTextColor
            }
    }

Write-Output ''
Write-Output 'Completed import.'