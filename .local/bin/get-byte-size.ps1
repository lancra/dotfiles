<#
.SYNOPSIS
Provides a user-friendly binary size for a byte count.

.DESCRIPTION
Converts a byte count to the smallest possible binary denomination that includes
whole numbers. Provides customizable formatting for the result.

.PARAMETER Count
The number of bytes to convert.

.PARAMETER Format
The output format to show. The provided options are json, padded, and plain. The
default option is padded.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [long] $Count,

    [Parameter()]
    [ValidateSet('json', 'padded', 'plain')]
    [string] $Format = 'padded'
)

function Format-Size {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
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
        if (-not $isLargestDenomination) {
            return $null
        }

        return [pscustomobject]@{
            Count = $Count / $DenominationCount
            Denomination = $Denomination
        }
    }
}

$size = (Format-Size -Count $Count -DenominationCount 1TB -Denomination 'TB') `
    ?? (Format-Size -Count $Count -DenominationCount 1GB -Denomination 'GB') `
    ?? (Format-Size -Count $Count -DenominationCount 1MB -Denomination 'MB') `
    ?? (Format-Size -Count $Count -DenominationCount 1KB -Denomination 'KB') `
    ?? (Format-Size -Count $Count -DenominationCount 1 -Denomination 'B')

switch ($Format) {
    'json' {
        return $size |
            ConvertTo-Json -Compress
    }
    'padded' {
        $displayCount = ('{0:N2}' -f $size.Count).PadLeft(6)
        $displayDenomination = $size.Denomination.PadLeft(2)
        return "$displayCount $displayDenomination"
    }
    'plain' {
        return "{0:N2} {1}" -f $size.Count, $size.Denomination
    }
    default { exit 1 }
}
