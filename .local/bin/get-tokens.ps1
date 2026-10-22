<#
.SYNOPSIS
Parses tokens from a line of text.

.DESCRIPTION
Identifies all regular expression matches of text surrounded by a specific
affix and returns the metadata for the match.

.PARAMETER Text
The line to retrieve tokens from.

.PARAMETER Affix
The text surrounding a value which denotes it as a token. The default is two
underscores.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter()]
    [AllowEmptyCollection()]
    [string] $Text,

    [Parameter()]
    [string] $Affix = '__'
)

$affixPattern = [Regex]::Escape($Affix)
$keyGroupName = 'key'
$variablePattern = "$affixPattern(?<$keyGroupName>[^\W_]\w*?)$affixPattern"

Select-String -InputObject $Text -Pattern $variablePattern -AllMatches |
    Select-Object -ExpandProperty Matches |
    ForEach-Object {
        [pscustomobject]@{
            Key = $_ |
                Select-Object -ExpandProperty Groups |
                Where-Object -Property Name -EQ $keyGroupName |
                Select-Object -ExpandProperty Value
            Index = $_.Index
            Length = $_.Length
        }
    }
