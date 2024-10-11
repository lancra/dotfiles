#Requires -Modules powershell-yaml
using module ../.config/snippets/snippet.psm1
using module ../.config/snippets/snippet-format-result.psm1

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$Source = "$env:XDG_CONFIG_HOME/snippets",
    [switch]$SkipVisualStudio
)

$snippetsPath = "$PSScriptRoot/../.config/snippets"

function Write-SnippetFormatResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [SnippetFormatResult]$Result
    )
    begin {
        $titleWidth = 20
        $countFormat = '{0:D3}'
    }
    process {
        $title = "$($Result.Title):".PadRight($titleWidth, ' ')

        $oldCount = $countFormat -f $Result.OldCount
        $newCount = $countFormat -f $Result.NewCount

        $hasChanges = $Result.HasChanges ? 'changed' : 'identical'

        Write-Output "$title $oldCount -> $newCount ($hasChanges)"
    }
}

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

function Read-SqlSnippet {
    [CmdletBinding()]
    [OutputType([System.IO.FileSystemInfo[]])]
    param ()
    begin {
        $temporaryDirectory = Join-Path -Path $env:TEMP -ChildPath (New-Guid).Guid
    }
    process {
        $files = @(Get-ChildItem -Path $Source -Filter '*.sql' -Recurse)
        if ($files.Length -gt 0) {
            New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
        }

        $files | ForEach-Object {
            $sections = & split-sql-snippet-sections.ps1 -Path $_.FullName |
                ConvertFrom-Json
            if ($null -eq $sections) {
                return
            }

            $prefix = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
            $snippet = [ordered]@{
                scope = 'sql'
            }

            $metadata = $sections |
                Select-Object -ExpandProperty metadata |
                ConvertFrom-Yaml
            $metadata.GetEnumerator() |
                ForEach-Object { $snippet[$_.Key] = $_.Value }

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
            $snippet['body'] = $body

            $snippetPath = Join-Path -Path $temporaryDirectory -ChildPath "$prefix.snippet.json"
            $snippet |
                ConvertTo-Json |
                Set-Content -Path $snippetPath
            [System.IO.FileInfo]::new($snippetPath)
        }
    }
}

$snippetPropertySelectors = @(
    # Add the filename (without extension) as a prefix unless it's already set.
    'prefix: (.prefix | to_array + [input_filename | match(".*\\\\(?<prefix>.*)\\.snippet\\.json").captures[0].string] | unique)',
    'title',
    'description',
    'scope: .scope | to_array',
    'body: .body | to_array',
    'placeholders'
)
$snippetFiles = Get-ChildItem -Path $Source -Filter '*.snippet.json' -Recurse

$sqlSnippetFiles = Read-SqlSnippet
$snippetFiles += $sqlSnippetFiles

$allSnippetsJson = jq --compact-output "{ $($snippetPropertySelectors -join ',') }" $snippetFiles |
    jq --slurp

if ($sqlSnippetFiles.Length -gt 0) {
    $temporaryDirectory = [System.IO.Path]::GetDirectoryName($sqlSnippetFiles[0].FullName)
    Remove-Item -Path $temporaryDirectory -Recurse
}

$scopesJson = $allSnippetsJson | jq --compact-output '[.[].scope[]] | unique'

$scopesJson |
    ConvertFrom-Json |
    ForEach-Object {
        $scope = $_
        $matchingSnippetsJson = $allSnippetsJson | jq --compact-output "[.[] | select(.scope[] | contains(`"$scope`"))]"

        # Convert snippets within the scope into key-value objects by the title.
        $vsCodeSnippetsJson = $matchingSnippetsJson | jq 'map({ (.title): del(.title, .scope, .placeholders) }) | add' | Out-String

        if ($scope -eq 'csharp' -and -not $SkipVisualStudio) {
            $visualStudioSnippets = [Snippet[]]($matchingSnippetsJson |
                # Convert placeholders from key-value objects into an array of objects with the key as a property.
                jq --compact-output 'map(if .placeholders != null then . + { "placeholders": (.placeholders | to_entries | map(. + .value | del(.value))) } else . end)' |
                jq --compact-output 'map(. + { placeholders: .placeholders | to_array })' |
                ConvertFrom-Json)
            & $snippetsPath/format-vs-snippets.ps1 -Snippets $script:visualStudioSnippets | Write-SnippetFormatResult
        } elseif ($scope -eq 'sql') {
            & $snippetsPath/format-ads-snippets.ps1 -Json $vsCodeSnippetsJson -Scope $scope | Write-SnippetFormatResult
        }

        & $snippetsPath/format-vscode-snippets.ps1 -Json $vsCodeSnippetsJson -Scope $scope | Write-SnippetFormatResult
    }

