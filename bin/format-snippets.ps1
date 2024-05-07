#Requires -Modules powershell-yaml

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$Source = "$env:XDG_CONFIG_HOME/snippets"
)

$visualStudioCodeTarget = "$env:APPDATA/Code/User/snippets"
$azureDataStudioTarget = "$env:APPDATA/azuredatastudio/User/snippets"
$visualStudioTarget = "$env:HOME/Documents/Visual Studio 2022/Code Snippets/Visual C#/My Code Snippets"
$visualStudioNamespace = 'http://schemas.microsoft.com/VisualStudio/2005/CodeSnippet'

class Snippet {
    [string[]]$Prefix
    [string]$Title
    [string]$Description
    [string[]]$Scope
    [string[]]$Body
    [SnippetPlaceholder[]]$Placeholders
}

class SnippetPlaceholder {
    [string]$Key
    [string]$Variable
    [string]$Tooltip
}

class SnippetLineResult {
    [string]$Line
    [System.Xml.XmlElement[]]$Literals
}

function Format-VisualStudioCodeSnippet {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Json,
        [Parameter(Mandatory)]
        [string]$Scope,
        [Parameter(Mandatory)]
        [int]$Padding
    )
    process {
        $filePath = "$visualStudioCodeTarget/$Scope.json"
        $oldCount = 0
        $hasChanges = $true
        if (Test-Path -Path $filePath) {
            $oldCount = jq 'length' $filePath
            $hasChanges = $null -ne ($Json | jd -set $filePath)
        }

        $newCount = $Json | jq 'length'

        $spaces = ''.PadLeft($Padding - $Scope.Length, ' ')

        $countFormat = '{0:D2}'
        $oldCountDisplay = $countFormat -f [int]$oldCount
        $newCountDisplay = $countFormat -f [int]$newCount

        $hasChangesDisplay = $hasChanges ? 'changed' : 'identical'

        Write-Output "vscode ${Scope}:$spaces $oldCountDisplay -> $newCountDisplay ($hasChangesDisplay)"
        Set-Content -Path $filePath -Value $Json
    }
}

function Format-AzureDataStudioSnippet {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Json,
        [Parameter(Mandatory)]
        [int]$Padding
    )
    process {
        $filePath = "$azureDataStudioTarget/sql.json"
        $oldCount = 0
        $hasChanges = $true
        if (Test-Path -Path $filePath) {
            $oldCount = jq 'length' $filePath
            $hasChanges = $null -ne ($Json | jd -set $filePath)
        }

        $newCount = $Json | jq 'length'

        $spaces = ''.PadLeft($Padding, ' ')

        $countFormat = '{0:D2}'
        $oldCountDisplay = $countFormat -f [int]$oldCount
        $newCountDisplay = $countFormat -f [int]$newCount

        $hasChangesDisplay = $hasChanges ? 'changed' : 'identical'

        Write-Output "ads:$spaces $oldCountDisplay -> $newCountDisplay ($hasChangesDisplay)"
        Set-Content -Path $filePath -Value $Json
    }
}

function Set-VisualStudioSnippetToken {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document,
        [Parameter()]
        [SnippetPlaceholder[]]$Placeholders,
        [Parameter()]
        [string]$Line
    )
    begin {
        $keyGroup = 'key'
        $defaultGroup = 'default'
        $placeholderRegex = "\$\{?(?<$keyGroup>[0-9]+):?(?<$defaultGroup>[A-Za-z0-9]*)\}?"
    }
    process {
        $newLine = $Line
        $newLine = $newLine.Replace('$0', '$end$')
        $newLine = $newLine.Replace('$TM_SELECTED_TEXT', '$selected$')
        $newLine = $newLine.Replace('$LINE_COMMENT', '//')

        $newLine = $newLine.Replace("`r`n", '\r\n')
        $newLine = $newLine.Replace("`n", '\n')
        $newLine = $newLine.Replace("`t", '\t')

        $literalElements = @()
        Select-String -InputObject $newLine -Pattern $placeholderRegex -AllMatches |
            Select-Object -ExpandProperty Matches |
            ForEach-Object {
                $key = $_.Groups[$keyGroup].Value
                $default = $_.Groups[$defaultGroup].Value

                $placeholder = $Placeholders |
                    Where-Object -Property Key -EQ $key |
                    Select-Object -First 1

                $id = $placeholder.Variable ?? $key

                $literalElement = $Document.CreateElement('Literal', $visualStudioNamespace)

                $idElement = $Document.CreateElement('ID', $visualStudioNamespace)
                $idElement.InnerText = $id
                [void]$literalElement.AppendChild($idElement)

                $toolTipElement = $Document.CreateElement('ToolTip', $visualStudioNamespace)
                $toolTipElement.InnerText = $placeholder.Tooltip
                [void]$literalElement.AppendChild($toolTipElement)

                $defaultElement = $Document.CreateElement('Default', $visualStudioNamespace)
                $defaultElement.InnerText = $default
                [void]$literalElement.AppendChild($defaultElement)

                $literalElements += $literalElement

                $matchValue = $_.Value
                $newLine = $newLine.Replace($matchValue, "`$$id`$")
            }

        @{
            Line = $newLine
            Literals = $literalElements
        }
    }
}

function Format-VisualStudioSnippet {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [Snippet[]]$Snippets,
        [Parameter(Mandatory)]
        [int]$Padding
    )
    begin {
        $bodySeparator = [System.Environment]::NewLine + '      '
    }
    process {
        New-Item -ItemType Directory -Path $visualStudioTarget -Force | Out-Null

        $oldSnippetFiles = Get-ChildItem -Path "$visualStudioTarget/*.snippet"
        $oldCount = $oldSnippetFiles |
            Measure-Object |
            Select-Object -ExpandProperty Count

        $hasChanges = $false

        foreach ($snippet in $Snippets) {
            $fileName = $snippet.Prefix[0]
            $tempPath = "$visualStudioTarget/$fileName.temp.snippet"
            $document = [System.Xml.XmlDocument]::new()

            $literalElements = @()
            $codeValue = ($snippet.Body |
                ForEach-Object {
                    $lineResult = Set-VisualStudioSnippetToken -Document $document -Placeholders $snippet.Placeholders -Line $_

                    if ($lineResult.Literals) {
                        $literalElements += $lineResult.Literals
                    }

                    $lineResult.Line
                }) -join $bodySeparator

            $declaration = $document.CreateXmlDeclaration('1.0', 'utf-8', '')
            [void]$document.AppendChild($declaration)

            $codeSnippetsElement = $document.CreateElement('CodeSnippets', $visualStudioNamespace)
            [void]$document.AppendChild($codeSnippetsElement)

            $codeSnippetElement = $document.CreateElement('CodeSnippet', $visualStudioNamespace)
            [void]$codeSnippetsElement.AppendChild($codeSnippetElement)

            $headerElement = $document.CreateElement('Header', $visualStudioNamespace)
            [void]$codeSnippetElement.AppendChild($headerElement)

            $titleElement = $document.CreateElement('Title', $visualStudioNamespace)
            $titleElement.InnerText = $snippet.Title
            [void]$headerElement.AppendChild($titleElement)

            $shortcutElement = $document.CreateElement('Shortcut', $visualStudioNamespace)
            $shortcutElement.InnerText = $fileName
            [void]$headerElement.AppendChild($shortcutElement)

            $descriptionElement = $document.CreateElement('Description', $visualStudioNamespace)
            $descriptionElement.InnerText = $snippet.Description
            [void]$headerElement.AppendChild($descriptionElement)

            $snippetTypesElement = $document.CreateElement('SnippetTypes', $visualStudioNamespace)
            [void]$headerElement.AppendChild($snippetTypesElement)

            $snippetTypeElement = $document.CreateElement('SnippetType', $visualStudioNamespace)
            $snippetTypeElement.InnerText = 'Expansion'
            [void]$snippetTypesElement.AppendChild($snippetTypeElement)

            $snippetElement = $document.CreateElement('Snippet', $visualStudioNamespace)
            [void]$codeSnippetElement.AppendChild($snippetElement)

            if ($literalElements) {
                $declarationsElement = $document.CreateElement('Declarations', $visualStudioNamespace)
                [void]$snippetElement.AppendChild($declarationsElement)

                $literalElements | ForEach-Object { [void]$declarationsElement.AppendChild($_) }
            }

            $codeElement = $document.CreateElement('Code', $visualStudioNamespace)
            $codeElement.SetAttribute('Language', 'csharp')
            [void]$snippetElement.AppendChild($codeElement)

            $codeCDataSection = $document.CreateCDataSection($codeValue)
            [void]$codeElement.AppendChild($codeCDataSection)

            $document.Save($tempPath)
            Add-Content -Path $tempPath -Value ''

            $path = "$visualStudioTarget/$fileName.snippet"
            $originalHash = $null
            $newHash = Get-FileHash -Path $tempPath -Algorithm SHA256 |
                Select-Object -ExpandProperty Hash
            if (Test-Path -Path $path) {
                $originalHash = Get-FileHash -Path $path -Algorithm SHA256 |
                    Select-Object -ExpandProperty Hash
            }

            if ($null -eq $originalHash -or $originalHash -ne $newHash) {
                $hasChanges = $true
            }
        }

        $newSnippetFiles = Get-ChildItem -Path "$visualStudioTarget/*.temp.snippet"
        $newCount = $newSnippetFiles |
            Measure-Object |
            Select-Object -ExpandProperty Count

        $oldSnippetFiles | Remove-Item
        $newSnippetFiles |
            ForEach-Object {
                $newPath = $_ -replace '.temp.snippet', '.snippet'
                Move-Item -Path $_ -Destination $newPath
            }

        $spaces = ''.PadLeft($Padding, ' ')
        $hasChangesDisplay = $hasChanges ? 'changed' : 'identical'
        Write-Output "vs:$spaces $oldCount -> $newCount ($hasChangesDisplay)"
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
                $body = $sections |
                    Select-Object -ExpandProperty parameters |
                    ForEach-Object -Begin { $script:parameterNumber = 1 } -Process {
                        $parameter = Format-SqlSnippetParameter -Line $_ -Number $script:parameterNumber
                        $script:parameterNumber++
                        $parameter
                    }
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
$maxScopeLength = [int]($scopesJson | jq '[.[] | length] | max')

$script:visualStudioSnippets = @()

$scopesJson |
    ConvertFrom-Json |
    ForEach-Object {
        $scope = $_
        $matchingSnippetsJson = $allSnippetsJson | jq --compact-output "[.[] | select(.scope[] | contains(`"$scope`"))]"

        # Convert snippets within the scope into key-value objects by the title.
        $vsCodeSnippetsJson = $matchingSnippetsJson | jq 'map({ (.title): del(.title, .scope, .placeholders) }) | add' | Out-String
        Format-VisualStudioCodeSnippet -Json $vsCodeSnippetsJson -Scope $scope -Padding $maxScopeLength

        if ($scope -eq 'csharp') {
            $script:visualStudioSnippets = [Snippet[]]($matchingSnippetsJson |
                # Convert placeholders from key-value objects into an array of objects with the key as a property.
                jq --compact-output 'map(if .placeholders != null then . + { "placeholders": (.placeholders | to_entries | map(. + .value | del(.value))) } else . end)' |
                jq --compact-output 'map(. + { placeholders: .placeholders | to_array })' |
                ConvertFrom-Json)
        } elseif ($scope -eq 'sql') {
            Format-AzureDataStudioSnippet -Json $vsCodeSnippetsJson -Padding ($maxScopeLength + 4)
        }
    }

Format-VisualStudioSnippet -Snippets $script:visualStudioSnippets -Padding ($maxScopeLength + 5)
