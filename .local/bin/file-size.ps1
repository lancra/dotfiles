<#
.SYNOPSIS
Displays a user-friendly size for all relevant files in a tabular format.

.DESCRIPTION
Determines the target paths to show based on the provided path. For each target
path, the right-aligned count is shown, then the right-aligned denomination is
shown, followed by the left-aligned name. The smallest possible denomination is
used where the whole number is limited to three digits. The name is shown after
the size.

.PARAMETER Path
The path to display sizes for. When a directory is provided, the sizes of all
children are shown. When a file is provided, the size of it is shown. When this
is not provided, the working directory is used.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter()]
    [string] $Path = '.'
)

class FileSize {
    [decimal] $Count
    [string] $Denomination
    [string] $Path

    FileSize([decimal] $count, [string] $denomination, [string] $path) {
        $this.Count = $count
        $this.Denomination = $denomination
        $this.Path = $path
    }

    [void] Print() {
        $displayCount = ('{0:N2}' -f $this.Count).PadLeft(6)
        $displayDenomination = $this.Denomination.PadLeft(2)

        Write-Host "$displayCount $displayDenomination " -ForegroundColor Yellow -NoNewline
        Write-Host $this.Path
    }
}

function Get-Size {
    [CmdletBinding()]
    [OutputType([FileSize])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    begin {
        function Format-Size {
            [CmdletBinding()]
            [OutputType([FileSize])]
            param(
                [Parameter(Mandatory)]
                [long] $Count,

                [Parameter(Mandatory)]
                [long] $DenominationCount,

                [Parameter(Mandatory)]
                [string] $Denomination
            )
            process {
                $isLargestDenomination = $Count -ge $DenominationCount -or $DenominationCount -eq 1
                return $isLargestDenomination ? [FileSize]::new($Count / $DenominationCount, $Denomination, $Path) : $null
            }
        }
    }
    process {
        $bytes = Get-Item -Path $Path |
            Select-Object -ExpandProperty Length
        return (Format-Size -Count $bytes -DenominationCount 1TB -Denomination 'TB') `
            ?? (Format-Size -Count $bytes -DenominationCount 1GB -Denomination 'GB') `
            ?? (Format-Size -Count $bytes -DenominationCount 1MB -Denomination 'MB') `
            ?? (Format-Size -Count $bytes -DenominationCount 1KB -Denomination 'KB') `
            ?? (Format-Size -Count $bytes -DenominationCount 1 -Denomination 'B')
    }
}

$item = Get-Item -Path $Path -ErrorAction SilentlyContinue
$targetPaths = @($Path)
if ($null -eq $item) {
    throw 'The provided path is invalid.'
} elseif ($item -is [System.IO.DirectoryInfo]) {
    $absolutePath = Resolve-Path -Path $Path
    $targetPaths = Get-ChildItem -Path $item.FullName -File |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { [System.IO.Path]::GetRelativePath($absolutePath, $_) }
}

$targetPaths |
    ForEach-Object {
        $size = Get-Size -Path $_
        $size.Print()
    }
