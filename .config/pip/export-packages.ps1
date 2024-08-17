[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

$homepageGroupName = 'Homepage'
& pip list --not-required --format json --verbose |
    ConvertFrom-Json |
    ForEach-Object {
        $metadataRelativePath = & pip show --files $_.name |
            Where-Object { $_ -match '.*.dist-info\\METADATA' } |
            ForEach-Object { $_.Trim() } |
            Select-Object -First 1
        $metadataPath = Join-Path -Path $_.location -ChildPath $metadataRelativePath

        $homepageMatch = Select-String -Path $metadataPath -Pattern "^Project-URL: Homepage, (?<$homepageGroupName>.*)|^Home-page: (?<$homepageGroupName>.*)"
        $homepageMatchGroup = $homepageMatch.Matches.Groups | Where-Object -Property Name -EQ $homepageGroupName
        [ordered]@{
            Id = $_.name
            Homepage = $homepageMatchGroup.Value
        }
    } |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target
