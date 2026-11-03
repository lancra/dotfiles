<#
.SYNOPSIS
Lists diagnostic rule severities for one or more configuration files.

.DESCRIPTION
Parses diagnostic rule severities from all provided configuration paths and
displays the associated levels for unique rule identifiers.

.PARAMETER Path
The configuration file path(s).

.PARAMETER RulePrefix
The optional rule identifier prefix to filter results by.

.PARAMETER Difference
When specified, only rule identifiers with different levels between the provided
paths are shown.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]] $Path,

    [Parameter()]
    [string] $RulePrefix,

    [switch] $Difference
)

class DiagnosticPath {
    [string] $Source
    [string] $Display

    DiagnosticPath([string] $source, [string] $display) {
        $this.Source = $source
        $this.Display = $display
    }

    [bool] Equals([object] $obj) {
        return $obj -is [DiagnosticPath] -and $this.Source -eq $obj.Source
    }

    [int] GetHashCode() {
        return $this.Source.GetHashCode()
    }
}

function Get-DiagnosticPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $SourcePath
    )
    process {
        $normalizedPaths = @($SourcePath) |
            ForEach-Object {
                $normalizedPath = $_ -replace '\\', '/'
                if ($normalizedPath.EndsWith('/')) {
                    $normalizedPath = $normalizedPath.Substring(0, $normalizedPath.Length - 1)
                }

                $normalizedPath
            }

        $commonPrefix = ''
        if (@($normalizedPaths).Length -gt 1) {
            $splitPaths = @()
            @($normalizedPaths) |
                ForEach-Object {
                    $splitPaths += ,@($_.Split('/'))
                }

            $minimumSegmentCount = @($splitPaths) |
                Measure-Object -Property Length -Minimum |
                Select-Object -ExpandProperty Minimum
            $commonSegments = @()
            for ($i = 0; $i -lt $minimumSegmentCount; $i++) {
                $segment = $splitPaths[0][$i]

                $unmatchedPathCount = @($splitPaths) |
                    Where-Object { $_[$i] -ne $segment } |
                    Measure-Object |
                    Select-Object -ExpandProperty Count
                if ($unmatchedPathCount -eq 0) {
                    $commonSegments += $segment
                } else {
                    break
                }
            }

            if ($commonSegments.Length -gt 0) {
                $commonPrefix = "$($commonSegments -join '/')/"
            }
        }

        @($normalizedPaths) |
            ForEach-Object {
                [DiagnosticPath]::new($_, $_.Substring($commonPrefix.Length))
            }
    }
}

class Diagnostic {
    [string] $Id
    [string] $Level

    Diagnostic([string] $id, [string] $level) {
        $this.Id = $id
        $this.Level = $level
    }
}

function Get-Diagnostic {
    [CmdletBinding()]
    [OutputType([Diagnostic[]])]
    param(
        [Parameter(Mandatory)]
        [DiagnosticPath] $DiagnosticPath
    )
    process {
        Get-Content -Path $DiagnosticPath.Source |
            ForEach-Object {
                if ($_ -match '^dotnet_diagnostic\.(?<id>.*?)\.severity = (?<level>.*?)$' -and
                    (-not $RulePrefix -or $matches.id.StartsWith($RulePrefix))) {
                    [Diagnostic]::new($matches.id, $matches.level)
                }
            }
    }
}

$diagnosticPaths = Get-DiagnosticPath -SourcePath $Path

$diagnostics = @{}
@($diagnosticPaths) |
    ForEach-Object {
        $diagnostics[$_] = Get-Diagnostic -DiagnosticPath $_
    }

$ids = $diagnostics.GetEnumerator() |
    Select-Object -ExpandProperty Value |
    Select-Object -ExpandProperty Id -Unique |
    Sort-Object
$maximumIdLength = [int]($ids |
    Measure-Object -Property Length -Maximum |
    Select-Object -ExpandProperty Maximum)

$tableColumns = @(
    @{ Label = 'RuleId'; Expression = { $_.RuleId }; Width = $maximumIdLength}
)
$diagnosticPaths |
    ForEach-Object {
        $tableColumns += @{ Label = $_.Display; Expression = { "`$_.$($_.Display)" | Invoke-Expression } }
    }

$ids |
    ForEach-Object {
        $id = $_
        $output = [pscustomobject]@{
            RuleId = $id
        }

        @($diagnosticPaths) |
            ForEach-Object {
                $matchingDiagnostic = $diagnostics[$_] |
                    Where-Object -Property Id -EQ $id
                $output |
                    Add-Member -NotePropertyName $_.Display -NotePropertyValue ($matchingDiagnostic.Level ?? 'N/A')
            }

        $output
    } |
    ForEach-Object {
        if (-not $Difference) {
            return $_
        }

        $uniqueLevels = $_.PSObject.Properties |
            Where-Object -Property Name -NE 'RuleId' |
            Select-Object -ExpandProperty Value -Unique

        if (@($uniqueLevels).Length -gt 1) {
            return $_
        }
    } |
    Format-Table -AutoSize
