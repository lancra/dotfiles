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
    [Parameter()]
    [AllowEmptyCollection()]
    [string[]] $Text,

    [Parameter(Mandatory)]
    [hashtable] $Token,

    [Parameter()]
    [string] $Affix = '__'
)

$Text |
    ForEach-Object {
        $line = $_
        $totalIndexOffset = 0

        & "$PSScriptRoot/get-tokens.ps1" -Text $line -Affix $Affix |
            ForEach-Object {
                $startIndex = $_.Index + $totalIndexOffset
                $endIndex = $_.Index + $_.Length + $totalIndexOffset

                $prefix = $startIndex -ne 0 ? $line.Substring(0, $startIndex) : ''
                $tokenValue = $Token[$_.Key]
                $suffix = $endIndex -ne $line.Length ? $line.Substring($endIndex, $line.Length - $endIndex) : ''

                $line = $prefix + $tokenValue + $suffix
                $totalIndexOffset += $tokenValue.Length - ($_.Key.Length + ($Affix.Length * 2))
            }

        $line
    }
