using module ../snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [Snippet]$Snippet,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

$visualStudioDirectory = Resolve-Path -Path $Configuration.TargetDirectory

$visualStudioPath = "$visualStudioDirectory/$Name.snippet"
if (-not (Test-Path -Path $visualStudioPath)) {
    Write-Error "The $Name Visual Studio snippet could not be found."
    exit 1
}

& bat --paging=never --language=xml --file-name "Visual Studio" $visualStudioPath
