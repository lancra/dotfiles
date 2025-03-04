[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter()]
    [string] $IgnorePath,

    [Parameter()]
    [int] $Depth = $null
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

    if ($IgnorePath) {
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

function Get-IndentCount {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [char] $Indent
    )
    process {
        Select-String -Path $Path -Pattern "^$Indent" -ErrorAction SilentlyContinue |
            Measure-Object |
            Select-Object -ExpandProperty Count
    }
}

$targets |
    ForEach-Object {
        if (-not (Test-TextFile -Path $_)) {
            return
        }

        $spaceIndentCount = Get-IndentCount -Path $_ -Indent ' '
        $tabIndentCount = Get-IndentCount -Path $_ -Indent "`t"

        if ($spaceIndentCount -ne 0 -and $tabIndentCount -ne 0) {
            [PSCustomObject]@{
                Path = $_
                Spaces = $spaceIndentCount
                Tabs = $tabIndentCount
            }
        }
    }
