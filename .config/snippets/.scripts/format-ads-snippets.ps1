using module ./snippets.psm1

[CmdletBinding(SupportsShouldProcess)]
[OutputType([SnippetFormatResult])]
param (
    [Parameter(Mandatory)]
    [SnippetScopeCollection]$Snippets,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

$targetDirectory = Resolve-Path -Path $Configuration.TargetDirectory
$filePath = Join-Path -Path $targetDirectory -ChildPath "$($Snippets.Scope).json"

$oldCount = 0
$hasChanges = $true
if (Test-Path -Path $filePath) {
    $oldCount = jq 'length' $filePath
    $hasChanges = $null -ne ($Snippets.Json | jd -set $filePath)
}

$newCount = $Snippets.Json | jq 'length'
Set-Content -Path $filePath -Value $Snippets.Json

[ordered]@{
    Scope = $Snippets.Scope
    Editor = 'ads'
    OldCount = $oldCount
    NewCount = $newCount
    HasChanges = $hasChanges
}
