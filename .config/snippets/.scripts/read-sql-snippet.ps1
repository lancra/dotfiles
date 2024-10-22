#Requires -Modules powershell-yaml
using module ./snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Path
)

function Format-SqlSnippetParameter {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$Line,
        [Parameter(Mandatory)]
        [int]$Number
    )
    begin {
        $quotedTypes = @{}
        @(
            'char',
            'date'
            'datetime'
            'datetime2'
            'datetimeoffset'
            'hierarchyid'
            'nchar'
            'ntext'
            'nvarchar'
            'smalldatetime'
            'sysname'
            'text'
            'time'
            'uniqueidentifier'
            'varchar'
            'xml'
        ) | ForEach-Object { $quotedTypes[$_] = $_ }
    }
    process {
        # DECLARE @<VARIABLE> <DATA_TYPE> [= <VALUE>]
        #        |           |             |
        #        FirstSpace  SecondSpace   Equals
        $firstSpaceIndex = $Line.IndexOf(' ')
        $secondSpaceIndex = $Line.IndexOf(' ', $firstSpaceIndex + 1)
        $equalsIndex = $Line.IndexOf('=', $secondSpaceIndex + 1)

        $name = $Line.Substring($firstSpaceIndex + 2, $secondSpaceIndex - $firstSpaceIndex - 2)
        $typeRaw = $Line.Substring(
            $secondSpaceIndex + 1,
            ($equalsIndex -ne -1 ? $equalsIndex - 1 : $Line.Length) - $secondSpaceIndex - 1);

        $typeParenthsesIndex = $typeRaw.IndexOf('(')
        $type = $typeParenthsesIndex -eq -1 ? $typeRaw : $typeRaw.Substring(0, $typeParenthsesIndex)
        $typeIsQuoted = $quotedTypes.ContainsKey($type)

        $valueRaw = "`${${Number}:$name}"
        $value = $typeIsQuoted ? "'$valueRaw'" : $valueRaw

        $newLine = "DECLARE @$name $typeRaw = $value"
        $newLine
    }
}

$sections = & "$env:SNIPPET_HOME/.scripts/split-sql-snippet-sections.ps1" -Path $Path |
    ConvertFrom-Json
if ($null -eq $sections) {
    return
}

$fileName = [System.IO.Path]::GetFileName($Path)
$prefix = $fileName -replace '.snippet.sql', ''

$metadata = $sections |
    Select-Object -ExpandProperty metadata |
    ConvertFrom-Yaml

$body = @()
if ($sections.parameters.Length -gt 0) {
    $script:parameterNumber = 1
    $body = @($sections |
        Select-Object -ExpandProperty parameters |
        ForEach-Object -Begin { $script:parameterNumber = 1 } -Process {
            $parameter = Format-SqlSnippetParameter -Line $_ -Number $script:parameterNumber
            $script:parameterNumber++
            $parameter
        })
}

$body += $sections | Select-Object -ExpandProperty body

return [Snippet]::new(
    $Path,
    $prefix,
    $metadata['title'],
    $metadata['description'],
    'sql',
    $body,
    @())
