using module ./snippet-format-result.psm1

[CmdletBinding(SupportsShouldProcess)]
[OutputType([SnippetFormatResult])]
param (
    [Parameter(Mandatory)]
    [string]$Json,
    [Parameter(Mandatory)]
    [string]$Scope
)

$filePath = "$env:APPDATA/azuredatastudio/User/snippets/$Scope.json"
$oldCount = 0
$hasChanges = $true
if (Test-Path -Path $filePath) {
    $oldCount = jq 'length' $filePath
    $hasChanges = $null -ne ($Json | jd -set $filePath)
}

$newCount = $Json | jq 'length'
Set-Content -Path $filePath -Value $Json

[ordered]@{
    Title = "ads $Scope"
    OldCount = $oldCount
    NewCount = $newCount
    HasChanges = $hasChanges
}
