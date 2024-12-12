[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

(& npm list --location=global --json |
    & jq -r '.dependencies | keys[]' |
    ForEach-Object {
        $homepage = & npm view --json $_ |
            & jq -r '.homepage'
        [ordered]@{
            Id = $_
            Homepage = $homepage
        }
    } |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target) 2> $null
