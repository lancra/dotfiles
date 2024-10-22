using module ./snippets.psm1

[CmdletBinding(SupportsShouldProcess)]
[OutputType([SnippetFormatResult])]
param (
    [Parameter(Mandatory)]
    [SnippetScopeCollection]$Snippets,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

$visualStudioTarget = Resolve-Path -Path $Configuration.TargetDirectory
$visualStudioNamespace = 'http://schemas.microsoft.com/VisualStudio/2005/CodeSnippet'

function New-LiteralElement {
    [CmdletBinding()]
    [OutputType([System.Xml.XmlElement])]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Tooltip,
        [Parameter(Mandatory)]
        [string]$Default,
        [Parameter()]
        [string]$Function
    )
    process {
        $literalElement = $Document.CreateElement('Literal', $visualStudioNamespace)

        $idElement = $Document.CreateElement('ID', $visualStudioNamespace)
        $idElement.InnerText = $Id
        [void]$literalElement.AppendChild($idElement)

        $toolTipElement = $Document.CreateElement('ToolTip', $visualStudioNamespace)
        $toolTipElement.InnerText = $Tooltip
        [void]$literalElement.AppendChild($toolTipElement)

        $defaultElement = $Document.CreateElement('Default', $visualStudioNamespace)
        $defaultElement.InnerText = $Default
        [void]$literalElement.AppendChild($defaultElement)

        if (-not [string]::IsNullOrEmpty($Function)) {
            $functionElement = $Document.CreateElement('Function', $visualStudioNamespace)
            $functionElement.InnerText = $Function
            [void]$literalElement.AppendChild($functionElement)
        }

        return $literalElement
    }
}

function Set-VisualStudioSnippetToken {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory)]
        [hashtable]$Markers,
        [Parameter()]
        [SnippetPlaceholder[]]$Placeholders,
        [Parameter()]
        [string]$Line
    )
    begin {
        $keyGroup = 'key'
        $defaultGroup = 'default'
        $placeholderRegex = "\$\{?(?<$keyGroup>[0-9]+):?(?<$defaultGroup>[A-Za-z0-9]*)\}?"

        $classNamePlaceholder = '$TM_FILENAME_BASE'
        $classNameId = 'classname'
    }
    process {
        $newLine = $Line
        $newLine = $newLine.Replace('$0', '$end$')
        $newLine = $newLine.Replace('$LINE_COMMENT', '//')
        $newLine = $newLine.Replace('$TM_SELECTED_TEXT', '$selected$')

        $newLine = $newLine.Replace("`r`n", '\r\n')
        $newLine = $newLine.Replace("`n", '\n')
        $newLine = $newLine.Replace("`t", '\t')

        $literalElements = @()
        if ($newLine.Contains($classNamePlaceholder)) {
            if ($null -eq $Markers[$classNameId]) {
                $Markers[$classNameId] = $classNameId

                $newClassNameLiteralElementParameters = @{
                    Document = $Document
                    Id = $classNameId
                    Tooltip = 'The current class.'
                    Default = 'ClassName'
                    Function = 'ClassName()'
                }
                $literalElements += New-LiteralElement @newClassNameLiteralElementParameters
            }

            $newLine = $newLine.Replace($classNamePlaceholder, "`$$classNameId`$")
        }

        Select-String -InputObject $newLine -Pattern $placeholderRegex -AllMatches |
            Select-Object -ExpandProperty Matches |
            ForEach-Object {
                $key = $_.Groups[$keyGroup].Value
                $default = $_.Groups[$defaultGroup].Value

                $placeholder = $Placeholders |
                    Where-Object -Property Key -EQ $key |
                    Select-Object -First 1

                $id = $placeholder.Variable ?? $key

                if ($null -eq $Markers[$key]) {
                    $Markers[$key] = $key

                    $newLiteralElementParameters = @{
                        Document = $Document
                        Id = $id
                        Tooltip = $placeholder.Tooltip
                        Default = $default
                    }
                    $literalElements += New-LiteralElement @newLiteralElementParameters
                }

                $matchValue = $_.Value
                $newLine = $newLine.Replace($matchValue, "`$$id`$")
            }

        @{
            Line = $newLine
            Literals = $literalElements
        }
    }
}

$bodySeparator = [System.Environment]::NewLine + '      '

New-Item -ItemType Directory -Path $visualStudioTarget -Force | Out-Null

$oldSnippetFiles = Get-ChildItem -Path "$visualStudioTarget/*.snippet"
$oldCount = $oldSnippetFiles |
    Measure-Object |
    Select-Object -ExpandProperty Count

$hasChanges = $false

foreach ($snippet in $Snippets.Values) {
    $fileName = $snippet.Prefix[0]
    $tempPath = "$visualStudioTarget/$fileName.temp.snippet"
    $document = [System.Xml.XmlDocument]::new()

    $placeholderMarkers = @{}
    $literalElements = @()
    $codeValue = ($snippet.Body |
        ForEach-Object {
            $setSnippetTokenParameters = @{
                Document = $document
                Markers = $placeholderMarkers
                Placeholders = $snippet.Placeholders
                Line = $_
            }
            $lineResult = Set-VisualStudioSnippetToken @setSnippetTokenParameters

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

[ordered]@{
    Scope = $Snippets.Scope
    Editor = 'vs'
    OldCount = $oldCount
    NewCount = $newCount
    HasChanges = $hasChanges
}
