[CmdletBinding(SupportsShouldProcess)]
param ()

$directoryPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'pip'
New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

$packagesPath = Join-Path $directoryPath -ChildPath 'packages.csv'
$properties = @(
    @{Name = 'Id'; Expression = { $_.name }}
)

& pip list --not-required --format json --verbose |
    ConvertFrom-Json |
    Select-Object -Property $properties |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $packagesPath
