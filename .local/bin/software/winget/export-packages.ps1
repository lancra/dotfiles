#Requires -Modules powershell-yaml
using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

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
        [string]$Id
    )
    process {
        New-Object -TypeName PSObject -Property ([ordered]@{
            Id = $Id
            DisplayName = ''
            Category = ''
            Tracking = ''
        })
    }
}

$persistedPackagesPath = "$env:XDG_DATA_HOME/software/winget.packages.yaml"

$persistedPackages = @()
if (Test-Path -Path $persistedPackagesPath) {
    $persistedPackages = Get-Content -Path $persistedPackagesPath |
        ConvertFrom-Yaml
}

$inMemoryExportPath = "$env:TEMP/winget-packages.$((New-Guid).Guid).json"
& winget export --output $inMemoryExportPath | Out-Null

$inMemoryPackages = Get-Content -Path $inMemoryExportPath |
    ConvertFrom-Json |
    Select-Object -ExpandProperty Sources |
    ForEach-Object {
        $sourceName = $_.SourceDetails.Name
        $_.Packages |
            Select-Object -ExpandProperty PackageIdentifier |
            ForEach-Object {
                New-ConfigPackage -Id "$_@$sourceName"
            }
    }
Remove-Item -Path $inMemoryExportPath | Out-Null

$ids = @()
$ids += $persistedPackages |
    Select-Object -ExpandProperty Id
$ids += $inMemoryPackages |
    Select-Object -ExpandProperty Id

$ids |
    Select-Object -Unique |
    ForEach-Object {
        $persistedPackage = $persistedPackages |
            Where-Object -Property Id -EQ $_
        $inMemoryPackage = $inMemoryPackages |
            Where-Object -Property Id -EQ $_

        if ($persistedPackage -and $inMemoryPackage) {
            $persistedPackage
        } elseif ($inMemoryPackage) {
            $inMemoryPackage
        }
    } |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            DisplayName = $_.DisplayName
            Category = $_.Category
            Tracking = $_.Tracking
        }

        [Installation]::new($id, $metadata)
    }
