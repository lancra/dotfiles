[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '.',

    [Parameter()]
    [string] $IgnorePath = '.gitignore',

    [Parameter()]
    [int] $Depth = $null,

    [switch] $All
)

Get-Command -Name fd -ErrorAction Stop | Out-Null
Get-Command -Name inspect -ErrorAction Stop | Out-Null

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

$spacesIdentifier = 'Spaces'
$tabsIdentifier = 'Tabs'
$mixedIdentifier = 'Mixed'
$otherIdentifier = 'Other'
$identifiers = @($spacesIdentifier, $tabsIdentifier, $mixedIdentifier, $otherIdentifier)

$targets |
    ForEach-Object {
        if (-not (Test-TextFile -Path $_)) {
            return
        }

        # Error action is set since some Windows system files can prevent reads and don't need to be checked anyways.
        $groups = Select-String -Path $_ -Pattern '^\s+' -ErrorAction SilentlyContinue |
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
            Group-Object

        $invalidGroupCount = $groups |
            Where-Object { $_.Name -eq $mixedIdentifier -or $_.Name -eq $otherIdentifier } |
            Measure-Object |
            Select-Object -ExpandProperty Count
        if ($groups.Length -le 1 -and $invalidGroupCount -eq 0 -and -not $All) {
            return
        }

        $outputSegments = $identifiers |
            ForEach-Object {
                $group = $groups |
                    Where-Object -Property Name -EQ $_

                $count = $group.Count ?? 0
                $isOther = $_ -eq $otherIdentifier

                $color = [System.Console]::ForegroundColor
                if ($count -ne 0 -and $isOther) {
                    $color = [System.ConsoleColor]::Magenta
                } elseif ($count -ne 0 -and ($groups.Length -gt 1 -or $group.Name -eq $mixedIdentifier)) {
                    $color = [System.ConsoleColor]::Red
                } elseif ($count -ne 0 -and $groups.Length -eq 1) {
                    $color = [System.ConsoleColor]::Green
                }

                $letter = $_[0]
                $ticker = '{0:D4}' -f $count
                $text = -not ($count -eq 0 -and $isOther) ? "$letter$ticker " : [string]::new(' ', 6)

                @{
                    Object = $text
                    ForegroundColor = $color
                }
            }

        $outputSegments += @{ Object = ($_ -replace '\\', '/') }

        for ($i = 0; $i -lt $outputSegments.Count; $i++) {
            $segment = $outputSegments[$i]
            $segment['NoNewline'] = $i -ne ($outputSegments.Count - 1)
            Write-Host @segment
        }
    }
