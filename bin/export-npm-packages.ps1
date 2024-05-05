[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

$directoryPath = [System.IO.Path]::GetDirectoryName($Target)
New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

& npm list --location=global --json |
    & jq -r '.dependencies | keys[]' |
    ForEach-Object {
        $packageMetadata = & npm view --json $_ |
            ConvertFrom-Json
        [ordered]@{
            Id = $_
            Homepage = $packageMetadata.homepage
        }
    } |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target
