[CmdletBinding(SupportsShouldProcess)]
param ()

$directoryPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'pip'
New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

$packagesPath = Join-Path $directoryPath -ChildPath 'packages.csv'

$homepageGroupName = 'Homepage'
& pip list --not-required --format json --verbose |
    ConvertFrom-Json |
    ForEach-Object {
        $distInfoDirectory = Get-ChildItem -Path $_.location -Filter "$($_.name)*.dist-info"
        $metadataPath = Join-Path -Path $distInfoDirectory.FullName -ChildPath 'METADATA'
        $homepageMatch = Select-String -Path $metadataPath -Pattern "^Project-URL: Homepage, (?<$homepageGroupName>.*)"
        $homepageMatchGroup = $homepageMatch.Matches.Groups | Where-Object -Property Name -EQ $homepageGroupName
        [ordered]@{
            Id = $_.name
            Homepage = $homepageMatchGroup.Value
        }
    } |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $packagesPath
