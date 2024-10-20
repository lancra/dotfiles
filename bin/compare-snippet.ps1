[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Name
)

$sourceDirectory = "$env:HOME/.config/snippets"
$sourceFileNames = @(
    "$Name.snippet.json",
    "$Name.sql"
)

$sourcePaths = @(Get-ChildItem -Path $sourceDirectory -Recurse -Include $sourceFileNames)
if ($sourcePaths.Length -gt 1) {
    $duplicatePaths = $sourcePaths | Select-Object -ExpandProperty FullName
    $duplicatePathsText = $duplicatePaths -join [System.Environment]::NewLine
    Write-Error "Multiple $Name snippets were found:$([System.Environment]::NewLine)$duplicatePathsText"
    exit 1
}

$sourcePath = $sourcePaths[0].FullName
if (-not (Test-Path -Path $sourcePath)) {
    Write-Error "The $Name snippet could not be found in the source directory."
    exit 1
}

$sourceLanguage = [System.IO.Path]::GetExtension($sourcePath).Substring(1)
& bat --paging=never --language=$sourceLanguage --file-name=Source $sourcePath

$visualStudioCodeDirectory = "$env:APPDATA/Code/User/snippets"
$title = ''
$scopes = @()

if ($sourceLanguage -eq 'json') {
    $title = Get-Content -Path $sourcePath |
        jq --compact-output --raw-output '.title'
    $scopes = @(Get-Content -Path $sourcePath |
        jq --compact-output '.scope | to_array' |
        ConvertFrom-Json)
} elseif ($sourceLanguage -eq 'sql') {
    $title = (& $sourceDirectory/split-sql-snippet-sections.ps1 -Path $sourcePath |
        ConvertFrom-Json |
        Select-Object -ExpandProperty metadata |
        ConvertFrom-Yaml)['title']
    $scopes = @('sql')
}

$script:missingVisualStudioCodeScope = $false
$visualStudioCodeSnippets = @{}
$scopes |
    ForEach-Object {
        $visualStudioScopePath = "$visualStudioCodeDirectory/$_.json"
        if (-not (Test-Path -Path $visualStudioScopePath)) {
            Write-Error "The Visual Studio Code snippets for $_ could not be found."
            $script:missingVisualStudioCodeScope = $true
            return
        }

        $content = Get-Content -Path $visualStudioScopePath |
            jq "with_entries(. | select(.key == `"$title`"))"
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

$visualStudioDirectory = "$env:HOME/Documents/Visual Studio 2022/Code Snippets/Visual C#/My Code Snippets"
$script:missingVisualStudio = $false
if ($scopes.Contains('csharp')) {
    $visualStudioPath = "$visualStudioDirectory/$Name.snippet"
    if (-not (Test-Path -Path $visualStudioPath)) {
        Write-Error "The $Name Visual Studio snippet could not be found."
        $script:missingVisualStudio = $true
        return
    }

    & bat --paging=never --language=xml --file-name "Visual Studio" $visualStudioPath
}

if ($script:missingVisualStudioCodeScope -or $script:missingVisualStudio) {
    exit 1
}
