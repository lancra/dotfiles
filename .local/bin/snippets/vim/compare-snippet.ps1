using module ../snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [Snippet]$Snippet,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

$directory = Resolve-Path -Path $Configuration.TargetDirectory

$script:missingScope = $false
$snippetContents = @{}
$Snippet.Scope |
    ForEach-Object {
        $scopeProperties = $Configuration.Scopes |
            Where-Object -Property Key -EQ $_ |
            Select-Object -ExpandProperty Properties
        $scope = $scopeProperties.override ?? $_
        $prefix = $Snippet.Prefix[0]
        $snippetScopePath = Join-Path -Path $directory -ChildPath $scope -AdditionalChildPath "$prefix.snippets"
        if (-not (Test-Path -Path $snippetScopePath)) {
            Write-Error "The VIM snippet for $prefix in scope $_ could not be found."
            $script:missingScope = $true
            return
        }

        $content = Get-Content -Path $snippetScopePath
        $contentStream = [System.IO.MemoryStream]::new([byte[]][char[]]($content -join ''))
        $contentHashInfo = Get-FileHash -InputStream $contentStream -Algorithm SHA256
        $contentHash = $contentHashInfo.Hash

        if (-not $snippetContents.ContainsKey($contentHash)) {
            $snippetContents[$contentHash] = @{
                Scopes = @()
                Content = $content
            }
        }

        $snippetContents[$contentHash].Scopes += $_
    }

$snippetContents.GetEnumerator() |
    ForEach-Object {
        $scopesDisplay = $_.Value.Scopes -join ' / '
        $displayName = "VIM ($scopesDisplay)"
        $_.Value.Content | & bat --paging=never --file-name=$displayName
    }

if ($script:missingScope) {
    exit 1
}
