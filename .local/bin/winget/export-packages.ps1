[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Target,
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

function New-ConfigPin {
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
        })
    }
}

$configurationDirectory = [System.IO.Path]::GetDirectoryName($Target)

function Export-Package {
    [CmdletBinding()]
    param()
    process {
        $configPackages = (Test-Path -Path $Target) ? (Import-Csv -Path $Target) : @()

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
            Export-Csv -Path $Target -UseQuotes AsNeeded
    }
}

function Export-Pin {
    [CmdletBinding()]
    param()
    begin {
        class ColumnDescriptor {
            [int]$Index
            [int]$Length

            ColumnDescriptor([int]$index, [int]$length) {
                $this.Index = $index
                $this.Length = $length
            }

            [string] GetFrom([string]$line) {
                return $line.Substring($this.Index, $this.Length).TrimEnd()
            }
        }

        $foundHeader = $false
        $foundSeparator = $false

        $idDescriptor = $null
        $sourceDescriptor = $null
    }
    process {
        & winget pin list |
            ForEach-Object {
                if ((-not $foundHeader) -and $_.StartsWith('Name ')) {
                    $foundHeader = $true

                    $idIndex = $_.IndexOf('Id')
                    $versionIndex = $_.IndexOf('Version')
                    $sourceIndex = $_.IndexOf('Source')
                    $pinTypeIndex = $_.IndexOf('Pin type')

                    $idDescriptor = [ColumnDescriptor]::new($idIndex, $versionIndex - $idIndex)
                    $sourceDescriptor = [ColumnDescriptor]::new($sourceIndex, $pinTypeIndex - $sourceIndex)
                } elseif ($foundHeader -and (-not $foundSeparator)) {
                    $foundSeparator = $true
                } elseif ($foundHeader -and $foundSeparator) {
                    $id = $idDescriptor.GetFrom($_)
                    $source = $sourceDescriptor.GetFrom($_)
                    New-ConfigPin -Id $id -Source $source
                }
            } |
            Sort-Object -Property Id |
            Export-Csv -Path "$configurationDirectory/pins.csv" -UseQuotes AsNeeded
    }
}

Export-Package
Export-Pin

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
