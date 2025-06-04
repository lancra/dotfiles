<#
.SYNOPSIS
Finds files with multiple indentation strategies.

.DESCRIPTION
For all files matching the provided parameters, any line starting with
whitespace is counted as being indented. These lines are grouped by the
indentation strategy, including mixed indentations and uncommon indentations,
such as form feeds or non-breaking spaces. The counts for each strategy are
displayed as fixed-width tickers to ensure a tabular output, along with the
filename and optional line count totals. By default, only files which are
identified as having mixed indentation are shown.

.PARAMETER Path
The path to check indentation for. When a directory is provided, all descendants
are checked which match supplied filter parameters. When a file is provided, it
is checked alone. When this parameter is not provided, the working directory is
used.

.PARAMETER IgnorePath
The path of the file which provides ignore patterns used when identifying
descendants of a directory.

.PARAMETER Depth
The maximum directory depth to identify files to check. When this parameter is
not provided, no maximum depth is used.

.PARAMETER All
Specifies that results for all files should be shown, regardless of whether
their indentation is determined to be invalid.

.PARAMETER ExcludeTotal
Specifies that the total indented line count and overall line count should be
excluded from the output.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '.',

    [Parameter()]
    [string] $IgnorePath = '.gitignore',

    [Parameter()]
    [int] $Depth = $null,

    [switch] $All,

    [switch] $ExcludeTotal
)

function Test-Executable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Executable,

        [Parameter(Mandatory)]
        [string] $Usage,

        [Parameter(Mandatory)]
        [string] $Installation
    )
    process {
        $executableCommand = Get-Command -Name $Executable -ErrorAction SilentlyContinue
        if (-not $executableCommand) {
            throw "The $Executable executable used for $Usage is unavailable. Install it by executing ``$Installation``"
        }
    }
}

Test-Executable -Executable 'fd' -Usage 'fast filesystem searches' -Installation 'winget install --exact --id sharkdp.fd'
Test-Executable -Executable 'inspect' -Usage 'file content type checks' -Installation 'cargo install --example inspect content_inspector'

$item = Get-Item -Path $Path -ErrorAction SilentlyContinue
if ($null -eq $item) {
    throw "Cannot find path '$Path' because it does not exist."
}

$targets = @($Path)
if ($item.PSIsContainer) {
    $fdOptions = @(
        '--hidden',
        '--type file',
        '--exclude .git'
    )

    if ($IgnorePath -and (Test-Path -Path $IgnorePath)) {
        $fdOptions += "--ignore-file $IgnorePath"
    }

    if ($Depth) {
        $fdOptions += "--max-depth $Depth"
    }

    $fdCommand = [scriptblock]::Create("fd $fdOptions . $Path")
    $targets = Invoke-Command -ScriptBlock $fdCommand
}

function Test-TextFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        $inspection = & inspect $Path
        $contentType = ($inspection -split ' ')[-1]
        return $contentType -ne 'binary'
    }
}

function Test-FileRead {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        $canRead = $true
        try {
            [System.IO.File]::OpenRead($Path).Close()
        }
        catch {
            $canRead = $false
        }

        $canRead
    }
}

function ConvertTo-Ticker {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int] $Count
    )
    process {
        '{0:D5}' -f $Count
    }
}

$spacesIdentifier = 'Spaces'
$tabsIdentifier = 'Tabs'
$mixedIdentifier = 'Mixed'
$otherIdentifier = 'Other'
$identifiers = @($spacesIdentifier, $tabsIdentifier, $mixedIdentifier, $otherIdentifier)

function New-GroupSegment {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [int] $Count,

        [Parameter(Mandatory)]
        [int] $TotalGroups
    )
    process {
        $color = [System.Console]::ForegroundColor
        if ($Count -ne 0 -and $Name -eq $otherIdentifier) {
            $color = [System.ConsoleColor]::Magenta
        } elseif ($Count -ne 0 -and ($TotalGroups -gt 1 -or $Name -eq $mixedIdentifier)) {
            $color = [System.ConsoleColor]::Red
        } elseif ($Count -ne 0 -and $TotalGroups -eq 1) {
            $color = [System.ConsoleColor]::Green
        }

        $letter = $Name[0]
        $ticker = ConvertTo-Ticker -Count $Count
        $groupDisplay = "$letter$ticker "

        $hideTicker = $Count -eq 0 -and $Name -eq $otherIdentifier
        $text = -not $hideTicker ? $groupDisplay : [string]::new(' ', $groupDisplay.Length)

        @{
            Object = $text
            ForegroundColor = $color
        }
    }
}

$targets |
    ForEach-Object {
        if (-not (Test-TextFile -Path $_)) {
            return
        }

        if (-not (Test-FileRead -Path $_)) {
            return
        }

        $groups = @(Select-String -Path $_ -Pattern '^\s+' |
            Select-Object -ExpandProperty Matches |
            Select-Object -ExpandProperty Value |
            ForEach-Object {
                $hasSpaces = $_.Contains(' ')
                $hasTabs = $_.Contains("`t")

                if ($hasSpaces -and $hasTabs) {
                    $mixedIdentifier
                } elseif ($hasSpaces) {
                    $spacesIdentifier
                } elseif ($hasTabs) {
                    $tabsIdentifier
                } else {
                    $otherIdentifier
                }
            } |
            Group-Object)

        $invalidGroupCount = $groups |
            Where-Object { $_.Name -eq $mixedIdentifier -or $_.Name -eq $otherIdentifier } |
            Measure-Object |
            Select-Object -ExpandProperty Count
        if ($groups.Length -le 1 -and $invalidGroupCount -eq 0 -and -not $All) {
            return
        }

        $totalLineCount = Get-Content -Path $_ |
            Measure-Object -Line |
            Select-Object -ExpandProperty Lines
        $totalLineTicker = ConvertTo-Ticker -Count $totalLineCount

        $indentedLineCount = $groups |
            Measure-Object -Property Count -Sum |
            Select-Object -ExpandProperty Sum
        $indentedLineTicker = ConvertTo-Ticker -Count $indentedLineCount

        $outputSegments = @()
        if (-not $ExcludeTotal) {
            $outputSegments += @{
                Object = "$indentedLineTicker/${totalLineTicker}: "
                ForegroundColor = [System.Console]::ForegroundColor
            }
        }

        $outputSegments += $identifiers |
            ForEach-Object {
                $group = $groups |
                    Where-Object -Property Name -EQ $_

                New-GroupSegment -Name $_ -Count ($group.Count ?? 0) -TotalGroups $groups.Length
            }

        $outputSegments += @{ Object = ($_ -replace '\\', '/') }

        for ($i = 0; $i -lt $outputSegments.Count; $i++) {
            $segment = $outputSegments[$i]
            $segment['NoNewline'] = $i -ne ($outputSegments.Count - 1)
            Write-Host @segment
        }
    }
