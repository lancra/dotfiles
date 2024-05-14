[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

(& npm list --location=global --json |
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
    Set-Content -Path $Target) 2> $null
