<#
.SYNOPSIS
Replaces tokens in one or more lines of text with the provided values.

.DESCRIPTION
Identifies all regular expression matches of text surrounded by a specific
affix, then replaces the content of the match with the corresponding value from
a hashtable, returning the line(s) with replaced text.

.PARAMETER Text
The line(s) to replace tokens in.

.PARAMETER Token
The hashtable containing the token values to replace with.

.PARAMETER Affix
The text surrounding a value which denotes it as a token. The default is two
underscores.
#>
[CmdletBinding()]
[OutputType([string[]])]
param(
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]] $Text,

    [Parameter(Mandatory)]
    [hashtable] $Token,

    [Parameter()]
    [string] $Affix = '__'
)

$affixPattern = [Regex]::Escape($Affix)
$keyGroupName = 'key'
$variablePattern = "$affixPattern(?<$keyGroupName>[^\W_]\w*?)$affixPattern"

$Text |
    ForEach-Object {
        $line = $_
        $totalIndexOffset = 0
        Select-String -InputObject $line -Pattern $variablePattern -AllMatches |
            Select-Object -ExpandProperty Matches |
            ForEach-Object {
                $tokenKey = $_ |
                    Select-Object -ExpandProperty Groups |
                    Where-Object -Property Name -EQ $keyGroupName |
                    Select-Object -ExpandProperty Value

                $startIndex = $_.Index + $totalIndexOffset
                $endIndex = $_.Index + $_.Length + $totalIndexOffset

                $prefix = $startIndex -ne 0 ? $line.Substring(0, $startIndex) : ''
                $tokenValue = $Token[$tokenKey]
                $suffix = $endIndex -ne $line.Length ? $line.Substring($endIndex, $line.Length - $endIndex) : ''

                $line = $prefix + $tokenValue + $suffix
                $totalIndexOffset += $tokenValue.Length - $_.Value.Length
            }

        $line
    }
