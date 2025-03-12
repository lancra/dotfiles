[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter()]
    [string] $Path = '.'
)

function Get-Size {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    begin {
        function Format-Size {
            [CmdletBinding()]
            [OutputType([string])]
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
                return $isLargestDenomination ? "{0:N2} $Denomination" -f ($Count / $DenominationCount) : $null
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
    $targetPaths = Get-ChildItem -Path $item.FullName -File |
        Select-Object -ExpandProperty FullName
}

$targetPaths |
    ForEach-Object {
        $size = Get-Size -Path $_

        Write-Host $size.PadLeft(9) -ForegroundColor Yellow -NoNewline
        Write-Host " $_"
    }
