using module ../.config/snippets/.scripts/snippets.psm1

[CmdletBinding()]
param (
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Name') {
            $validNames = Get-ChildItem -Path $env:SNIPPET_HOME -Recurse -Filter '*.snippet.*' |
                ForEach-Object {
                    $fileName = [System.IO.Path]::GetFileName($_)
                    $dotIndex = $fileName.IndexOf('.snippet')
                    $fileName.Substring(0, $dotIndex)
                } |
                Sort-Object
            $validNames -like "$wordToComplete*"
        }
    })]
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter()]
    [ValidateScript({
        $_ -in (& "$env:SNIPPET_HOME/.scripts/get-definition-keys.ps1")},
        ErrorMessage = 'Definition not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Definition') {
            $validDefinitions = (& "$env:SNIPPET_HOME/.scripts/get-definition-keys.ps1")
            $validDefinitions -like "$wordToComplete*"
        }
    })]
    [string[]]$Definition = @()
)

$snippets = [SnippetCollection]::FromDirectory($env:SNIPPET_HOME)
$snippet = $snippets.ForPrefix($Name)

if ($null -eq $snippet) {
    Write-Error "The $Name snippet could not be found in the source directory."
    exit 1
}

if ($Definition.Count -eq 0 -or $Definition -contains 'source') {
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
