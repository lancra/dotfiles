using module ./snippets.psm1

[CmdletBinding(SupportsShouldProcess)]
[OutputType([SnippetFormatResult])]
param (
    [Parameter(Mandatory)]
    [SnippetScopeCollection]$Snippets,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

$vimScope = $Configuration.ScopeOverrides.$Scope ?? $Scope

$targetDirectory = Resolve-Path -Path $Configuration.TargetDirectory
$targetScopeDirectory = Join-Path -Path $targetDirectory -ChildPath $vimScope
New-Item -ItemType Directory -Path $targetScopeDirectory -Force | Out-Null

$oldSnippetFiles = Get-ChildItem -Path "$targetScopeDirectory/*.snippets"
$oldCount = $oldSnippetFiles |
    Measure-Object |
    Select-Object -ExpandProperty Count

$hasChanges = $false
foreach ($snippet in $Snippets.Values) {
    $fileName = $snippet.Prefix[0]
    $tempPath = "$targetScopeDirectory/$fileName.snippets.temp"

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine("snippet $fileName `"$($snippet.Title)`"")
    $snippet.Body |
        ForEach-Object {
            $newLine = $_
            $newLine = $newLine.Replace('$TM_SELECTED_TEXT', '${VISUAL}')
            $newLine = $newLine.Replace('$LINE_COMMENT', '//')
            [void]$builder.AppendLine($newLine)
        }
    [void]$builder.AppendLine('endsnippet')

    Set-Content -Path $tempPath -Value ($builder.ToString())

    $path = "$targetScopeDirectory/$fileName.snippets"
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

$newSnippetFiles = Get-ChildItem -Path "$targetScopeDirectory/*.snippets.temp"
$newCount = $newSnippetFiles |
    Measure-Object |
    Select-Object -ExpandProperty Count

$oldSnippetFiles | Remove-Item
$newSnippetFiles |
    ForEach-Object {
        $newPath = $_ -replace '.snippets.temp', '.snippets'
        Move-Item -Path $_ -Destination $newPath
    }

[ordered]@{
    Scope = $Snippets.Scope
    Editor = 'vim'
    OldCount = $oldCount
    NewCount = $newCount
    HasChanges = $hasChanges
}
