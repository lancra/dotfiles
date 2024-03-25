[CmdletBinding()]
param (
    [switch]$IncludeSources,
    [switch]$IncludeProperties
)

enum PackageTracking {
    # Represents a package tracked for initial installation and any updates.
    Full

    # Represents a package tracked for initial installation only.
    # Typically due to updates not being properly handled by winget.
    Partial

    # Represents an untracked package that is a dependency of other software.
    None
}

function New-ConfigPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        [string]$Source
    )
    process {
        New-Object -TypeName PSObject -Property ([ordered]@{
            Id = $Id
            Source = $Source
            Name = ''
            Tracking = ''
            Category = ''
        })
    }
}

$configurationDirectory = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '.config','winget'
$packagesCsvPath = Join-Path -Path $configurationDirectory -ChildPath 'packages.csv'
$configPackages = (Test-Path -Path $packagesCsvPath) ? (Import-Csv -Path $packagesCsvPath) : @()

$packagesJsonPath = Join-Path -Path $configurationDirectory -ChildPath 'packages.json'
& winget export --output $packagesJsonPath | Out-Null

$sources = @()
$wingetPackages = @()

$wingetPackagesObject = Get-Content -Path $packagesJsonPath |
    ConvertFrom-Json
$wingetPackagesObject | Select-Object -ExpandProperty Sources |
    ForEach-Object {
        $source = New-Object -TypeName PSObject -Property ([ordered]@{
            Id = $_.SourceDetails.Identifier
            Name = $_.SourceDetails.Name
            Type = $_.SourceDetails.Type
            Argument = $_.SourceDetails.Argument
        })
        $sources += $source

        $_.Packages |
            Select-Object -ExpandProperty PackageIdentifier |
            ForEach-Object {
                $wingetPackages += New-ConfigPackage -Id $_ -Source $source.Name
            }
    }

Remove-Item -Path $packagesJsonPath

if ($IncludeSources) {
    $sourcesJsonPath = Join-Path -Path $configurationDirectory -ChildPath 'sources.json'
    $sources | ConvertTo-Json |
        Set-Content -Path $sourcesJsonPath
}

$ids = @()
$ids += $configPackages | Select-Object -ExpandProperty Id
$ids += $wingetPackages | Select-Object -ExpandProperty Id
$ids | Select-Object -Unique |
    Sort-Object |
    ForEach-Object {
        $configPackage = $configPackages | Where-Object -Property Id -EQ $_ |
            Select-Object -First 1
        $wingetPackage = $wingetPackages | Where-Object -Property Id -EQ $_ |
            Select-Object -First 1

        if ($configPackage -and $wingetPackage) {
            $configPackage
        } elseif ($wingetPackage) {
            $wingetPackage
        }
    } |
    Export-Csv -Path $packagesCsvPath -UseQuotes AsNeeded

if ($IncludeProperties) {
    $propertiesJsonPath = Join-Path -Path $configurationDirectory -ChildPath 'properties.json'
    [ordered]@{
        Schema = $wingetPackagesObject.'$schema'
        Date = $wingetPackagesObject.CreationDate
        Version = $wingetPackagesObject.WinGetVersion
    } |
        ConvertTo-Json |
        Set-Content -Path $propertiesJsonPath
}
