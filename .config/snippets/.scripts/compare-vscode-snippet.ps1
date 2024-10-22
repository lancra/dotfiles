using module ./snippets.psm1

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [Snippet]$Snippet,
    [Parameter(Mandatory)]
    [SnippetEditor]$Configuration
)

$visualStudioCodeDirectory = Resolve-Path -Path $Configuration.TargetDirectory

$script:missingVisualStudioCodeScope = $false
$visualStudioCodeSnippets = @{}
$Snippet.Scope |
    ForEach-Object {
        $visualStudioScopePath = "$visualStudioCodeDirectory/$_.json"
        if (-not (Test-Path -Path $visualStudioScopePath)) {
            Write-Error "The Visual Studio Code snippets for $_ could not be found."
            $script:missingVisualStudioCodeScope = $true
            return
        }

        $content = Get-Content -Path $visualStudioScopePath |
            jq "with_entries(. | select(.key == `"$($Snippet.Title)`"))"
        $contentStream = [System.IO.MemoryStream]::new([byte[]][char[]]($content -join ''))
        $contentHashInfo = Get-FileHash -InputStream $contentStream -Algorithm SHA256
        $contentHash = $contentHashInfo.Hash

        if (-not $visualStudioCodeSnippets.ContainsKey($contentHash)) {
            $visualStudioCodeSnippets[$contentHash] = @{
                Scopes = @()
                Content = $content
            }
        }

        $visualStudioCodeSnippets[$contentHash].Scopes += $_
    }

$visualStudioCodeSnippets.GetEnumerator() |
    ForEach-Object {
        $scopesDisplay = $_.Value.Scopes -join ' / '
        $displayName = "Visual Studio Code ($scopesDisplay)"
        $_.Value.Content | & bat --paging=never --language=json --file-name=$displayName
    }

if ($script:missingVisualStudioCodeScope) {
    exit 1
}
