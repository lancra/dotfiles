using module ../.config/snippets/snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Name
)

$snippets = [SnippetCollection]::FromDirectory("$env:XDG_CONFIG_HOME/snippets")
$snippet = $snippets.ForPrefix($Name)

if ($null -eq $snippet) {
    Write-Error "The $Name snippet could not be found in the source directory."
    exit 1
}

$sourceLanguage = [System.IO.Path]::GetExtension($snippet.Path).Substring(1)
& bat --paging=never --language=$sourceLanguage --file-name=Source $snippet.Path

$allSnippetsFound = $true
$editors = [SnippetEditor]::FromConfiguration()
foreach ($editor in $editors) {
    if (-not $editor.Comparable) {
        continue
    }

    if ($null -ne $editor.Scopes) {
        $sharedScopes = $editor.Scopes | Where-Object {$snippet.Scope -Contains $_}
        if ($sharedScopes.Count -eq 0) {
            continue
        }
    }

    $scriptPath = "$env:XDG_CONFIG_HOME/snippets/compare-$($editor.Key)-snippet.ps1"
    & $scriptPath -Snippet $snippet -Configuration $editor

    if ($LASTEXITCODE -ne 0) {
        $allSnippetsFound = $false
    }
}

if (-not $allSnippetsFound) {
    exit 1
}
