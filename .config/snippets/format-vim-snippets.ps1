using module ./snippet.psm1
using module ./snippet-format-result.psm1

[CmdletBinding(SupportsShouldProcess)]
[OutputType([SnippetFormatResult])]
param (
    [Parameter(Mandatory)]
    [Snippet[]]$Snippets,
    [Parameter(Mandatory)]
    [string]$Scope
)

$scopeOverrides = Get-Content -Path "$env:XDG_CONFIG_HOME/snippets/config.json" |
ConvertFrom-Json |
Select-Object -ExpandProperty scopes |
Select-Object -ExpandProperty vim
$vimScope = $scopeOverrides.$Scope ?? $Scope

$targetDirectory = "$env:XDG_CONFIG_HOME/vim/UltiSnips/$vimScope"
New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

$oldSnippetFiles = Get-ChildItem -Path "$targetDirectory/*.snippets"
$oldCount = $oldSnippetFiles |
    Measure-Object |
    Select-Object -ExpandProperty Count

$hasChanges = $false
foreach ($snippet in $Snippets) {
    $fileName = $snippet.Prefix[0]
    $tempPath = "$targetDirectory/$fileName.snippets.temp"

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

    $path = "$targetDirectory/$fileName.snippets"
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

$newSnippetFiles = Get-ChildItem -Path "$targetDirectory/*.snippets.temp"
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
    Scope = $Scope
    Editor = 'vim'
    OldCount = $oldCount
    NewCount = $newCount
    HasChanges = $hasChanges
}
