using module ../.config/snippets/.scripts/snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter()]
    [string[]]$Definition = @()
)

$sourceDefinitions = @('source', 'src')

$snippets = [SnippetCollection]::FromDirectory($env:SNIPPET_HOME)
$snippet = $snippets.ForPrefix($Name)

if ($null -eq $snippet) {
    Write-Error "The $Name snippet could not be found in the source directory."
    exit 1
}

$sharedSourceDefinitions = $Definition | Where-Object {$sourceDefinitions -contains $_}
if ($Definition.Count -eq 0 -or $sharedSourceDefinitions.Count -ne 0) {
    $sourceLanguage = [System.IO.Path]::GetExtension($snippet.Path).Substring(1)
    & bat --paging=never --language=$sourceLanguage --file-name=Source $snippet.Path
}

$allSnippetsFound = $true
$editors = [SnippetEditor]::FromConfiguration()

foreach ($editor in $editors) {
    if ($Definition.Count -ne 0 -and -not ($Definition -contains $editor.Key)) {
        continue
    }

    if ($null -ne $editor.Scopes) {
        $sharedScopes = $editor.Scopes | Where-Object {$snippet.Scope -contains $_}
        if ($sharedScopes.Count -eq 0) {
            continue
        }
    }

    $scriptPath = "$env:SNIPPET_HOME/.scripts/$($editor.Key)/compare-snippet.ps1"
    if (-not (Test-Path -Path $scriptPath)) {
        continue
    }

    & $scriptPath -Snippet $snippet -Configuration $editor

    if ($LASTEXITCODE -ne 0) {
        $allSnippetsFound = $false
    }
}

if (-not $allSnippetsFound) {
    exit 1
}
