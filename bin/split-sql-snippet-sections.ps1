[CmdletBinding()]
[OutputType([string])]
param (
    [Parameter(Mandatory)]
    [string]$Path
)

$frontMatter = @{
    metadata = @()
    parameters = @()
    body = @()
}

$frontMatterSeparator = '---'
$prefix = [System.IO.Path]::GetFileNameWithoutExtension($Path)

$fileLines = Get-Content -Path $Path
$frontMatterSeparatorIndexes = @(0..($fileLines.Count - 1) | Where-Object { $fileLines[$_] -eq $frontMatterSeparator })

$frontMatterSeparatorCount = $frontMatterSeparatorIndexes.Length
if ($frontMatterSeparatorCount -in @(0, 1)) {
    Write-Error "sql.${prefix}: Expected 2 or 3 front matter separators but found $frontMatterSeparatorCount."
    exit 1
}

$lastFrontMatterSeparatorIndex = $frontMatterSeparatorIndexes[1]
$frontMatter.Metadata = @($fileLines[($frontMatterSeparatorIndexes[0] + 1)..($lastFrontMatterSeparatorIndex - 1)]) |
    ForEach-Object {
        # Remove comment from each metadata value.
        $_.Substring(2)
    }

if ($frontMatterSeparatorCount -gt 2) {
    $lastFrontMatterSeparatorIndex = $frontMatterSeparatorIndexes[2]
    $frontMatter.Parameters = $fileLines[($frontMatterSeparatorIndexes[1] + 1)..($lastFrontMatterSeparatorIndex - 1)]
}

$frontMatter.Body = $fileLines[($lastFrontMatterSeparatorIndex + 1)..($fileLines.Length - 1)]

$frontMatter | ConvertTo-Json
