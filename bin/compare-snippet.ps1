using module ../.config/snippets/.scripts/snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Name,
    [Parameter()]
    [string[]]$Editor = @()
)

$snippets = [SnippetCollection]::FromDirectory($env:SNIPPET_HOME)
$snippet = $snippets.ForPrefix($Name)

if ($null -eq $snippet) {
    Write-Error "The $Name snippet could not be found in the source directory."
    exit 1
}

$sourceLanguage = [System.IO.Path]::GetExtension($snippet.Path).Substring(1)
& bat --paging=never --language=$sourceLanguage --file-name=Source $snippet.Path

$allSnippetsFound = $true
$editors = [SnippetEditor]::FromConfiguration()

foreach ($configuredEditor in $editors) {
    if ($Editor.Count -ne 0 -and -not ($Editor -contains $configuredEditor.Key)) {
        continue
    }

    if (-not $configuredEditor.Comparable) {
        continue
    }

    if ($null -ne $configuredEditor.Scopes) {
        $sharedScopes = $configuredEditor.Scopes | Where-Object {$snippet.Scope -Contains $_}
        if ($sharedScopes.Count -eq 0) {
            continue
        }
    }

    $scriptPath = "$env:SNIPPET_HOME/.scripts/$($configuredEditor.Key)/compare-snippet.ps1"
    & $scriptPath -Snippet $snippet -Configuration $configuredEditor

    if ($LASTEXITCODE -ne 0) {
        $allSnippetsFound = $false
    }
}

if (-not $allSnippetsFound) {
    exit 1
}
