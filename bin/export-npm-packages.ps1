[CmdletBinding(SupportsShouldProcess)]
param ()

$directoryPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'npm'
New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

$packagesPath = Join-Path $directoryPath -ChildPath 'packages.csv'

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
    Set-Content -Path $packagesPath
