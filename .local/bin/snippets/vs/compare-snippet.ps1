using module ../snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [Snippet]$Snippet,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

# NOTE: This approach must be modified for snippets that have multiple scopes supported by Visual Studio.
$scopeProperties = $Configuration.Scopes |
    Where-Object { $Snippet.Scope -contains $_.Key } |
    Select-Object -ExpandProperty Properties

$baseVisualStudioDirectory = Join-Path -Path $Configuration.TargetDirectory -ChildPath $scopeProperties.directory
$visualStudioDirectory = Resolve-Path -Path $baseVisualStudioDirectory

$visualStudioPath = "$visualStudioDirectory/$Name.snippet"
if (-not (Test-Path -Path $visualStudioPath)) {
    Write-Error "The $Name Visual Studio snippet could not be found."
    exit 1
}

& bat --paging=never --language=xml --file-name "Visual Studio" $visualStudioPath
