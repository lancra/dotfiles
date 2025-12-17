<#
.SYNOPSIS
Gets the latest version of a specified NuGet package.

.DESCRIPTION
The provided sources are searched for the specified package identifier. The
resulting versions are ordered using a natural sort to ensure the latest version
appears first. The first result is then output in the provided format. If usage
of the clipboard has been enabled, the output is also copied there.

.PARAMETER Id
The identifier of the NuGet package to find.

.PARAMETER Output
The format to provide the resulting package as.

CentralPackageManagement: Outputs the PackageVersion and PackageReference MSBuild properties.
Open: Opens the package on NuGet.org.
PackageReference: Outputs the PackageReference MSBuild property.
PackageVersion: Outputs the PackageReference MSBuild property.
Version: Outputs the version.

.PARAMETER Source
The sources to check for the package in. The NuGet API is provided as a default.

.PARAMETER Minimum
The inclusive minimum package version to limit the search to.

.PARAMETER Maximum
The exclusive maximum package version to limit the search to.

.PARAMETER IncludePrerelease
Specifies that prerelease versions should be included in the search.

.PARAMETER UseClipboard
Specifies that the output should also be copied to the clipboard. The script
will force input at a prompt after this action, and restore the previous
clipboard contents upon completion.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Id,

    [Parameter()]
    [ValidateSet(
        'CentralPackageManagement', 'cpm',
        'Open', 'o',
        'PackageReference', 'pr',
        'PackageVersion', 'pv',
        'Version', 'v')]
    [string] $Output = 'CentralPackageManagement',

    [Parameter()]
    [string[]] $Source = @('https://api.nuget.org/v3/index.json'),

    [Parameter()]
    [string] $Minimum,

    [Parameter()]
    [string] $Maximum,

    [switch] $IncludePrerelease,

    [switch] $UseClipboard
)

class Package {
    [string] $Id
    [PackageVersion] $Version

    Package([string] $id, [PackageVersion] $version) {
        $this.Id = $id
        $this.Version = $version
    }
}

class PackageVersion : System.IComparable {
    [string] $Value
    [int[]] $Release
    [string[]] $Prerelease

    PackageVersion([string] $value) {
        $this.Value = $value
        $this.Prerelease = @()

        $releaseText = $value
        $separatorIndex = $value.IndexOf('-')
        if ($separatorIndex -ne -1) {
            $releaseText = $value.Substring(0, $separatorIndex)

            $prereleaseText = $value.Substring($separatorIndex + 1)
            if (-not [string]::IsNullOrEmpty($prereleaseText)) {
                $this.Prerelease = @($prereleaseText.Split('.'))
            }
        }

        $this.Release = @($releaseText.Split('.') |
            ForEach-Object { [int]::Parse($_) })
    }

    [int] CompareTo($other) {
        if (-not ($other -is [PackageVersion])) {
            throw "Unable to compare PackageVersion to $($other.GetType())."
        }

        $maxReleaseSegments = [int]::Max($this.Release.Length, $other.Release.Length)
        for ($i = 0; $i -lt $maxReleaseSegments; $i++) {
            if ($i -gt ($this.Release.Length - 1)) {
                return -1
            }

            if ($i -gt ($other.Release.Length - 1)) {
                return 1
            }

            $thisSegment = $this.Release[$i]
            $otherSegment = $other.Release[$i]
            $comparison = $thisSegment.CompareTo($otherSegment)
            if ($comparison -ne 0) {
                return $comparison
            }
        }

        $maxPrereleaseSegments = [int]::Max($this.Prerelease.Length, $other.Prerelease.Length)
        for ($i = 0; $i -lt $maxPrereleaseSegments; $i++) {
            if ($i -gt ($this.Prerelease.Length - 1)) {
                return 1
            }

            if ($i -gt ($other.Prerelease.Length - 1)) {
                return -1
            }

            $thisSegment = $this.Prerelease[$i]
            $otherSegment = $other.Prerelease[$i]

            $thisSegmentNumber = $null
            $otherSegmentNumber = $null
            if ([int]::TryParse($thisSegment, [ref] $thisSegmentNumber) -and
                [int]::TryParse($otherSegment, [ref] $otherSegmentNumber)) {
                $comparison = $thisSegmentNumber.CompareTo($otherSegmentNumber)
            } else {
                $comparison = $thisSegment.CompareTo($otherSegment)
            }

            if ($comparison -ne 0) {
                return $comparison
            }
        }

        return 0
    }
}

$prompt = 'Output copied to clipboard. Press enter to continue'

function Get-CentralPackageManagement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Package] $Package
    )
    process {
        Get-PackageVersion -Package $Package
        Get-PackageReference -Package $Package
    }
}

function Open-Package {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Package] $Package
    )
    process {
        Start-Process -FilePath "https://www.nuget.org/packages/$($Package.Id)/$($Package.Version.Value)"
    }
}

function Get-PackageReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Package] $Package
    )
    process {
        $output = "<PackageReference Include=`"$($Package.Id)`" />"
        Write-Output $output
        if (-not $UseClipboard) {
            return
        }

        Set-Clipboard -Value $output
        Read-Host -Prompt $prompt |
            Out-Null
    }
}

function Get-PackageVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Package] $Package
    )
    process {
        $output = "<PackageVersion Include=`"$($Package.Id)`" Version=`"$($Package.Version.Value)`" />"
        Write-Output $output
        if (-not $UseClipboard) {
            return
        }

        Set-Clipboard -Value $output
        Read-Host -Prompt $prompt |
            Out-Null
    }
}

function Get-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Package] $Package
    )
    process {
        $output = $Package.Version.Value
        Write-Output $output
        if (-not $UseClipboard) {
            return
        }

        Set-Clipboard -Value $output
        Read-Host -Prompt $prompt |
            Out-Null
    }
}

$searchArguments = @(
    $Id,
    '--exact-match',
    '--format json'
    )

@($Source) |
    ForEach-Object {
        $searchArguments += "--source '$_'"
    }

if ($IncludePrerelease) {
    $searchArguments += '--prerelease'
}

$minimumVersion = -not [string]::IsNullOrEmpty($Minimum) ? [PackageVersion]::new($Minimum) : $null
$maximumVersion = -not [string]::IsNullOrEmpty($Maximum) ? [PackageVersion]::new($Maximum) : $null

$packages = @("dotnet package search $searchArguments" |
    Invoke-Expression |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'searchResult' |
    Select-Object -First 1 |
    Select-Object -ExpandProperty 'packages' |
    ForEach-Object {
        [Package]::new($_.id, [PackageVersion]::new($_.version))
    }) |
    Where-Object {
        $null -eq $minimumVersion -or $_.Version -ge $minimumVersion
    } |
    Where-Object {
        $null -eq $maximumVersion -or $_.Version -lt $maximumVersion
    } |
    Sort-Object -Property Version -Descending

if ($packages.Length -eq 0) {
    Write-Output "`e[31mNo package `e[4m$Id`e[24m was found on NuGet.`e[39m"
    exit 1
}

$package = $packages |
    Select-Object -First 1

if ($UseClipboard) {
    $clipboard = Get-Clipboard
}

try {
    switch ($Output) {
        { @('CentralPackageManagement', 'cpm') -contains $_ } { Get-CentralPackageManagement -Package $package }
        { @('Open', 'o') -contains $_ } { Open-Package -Package $package }
        { @('PackageReference', 'pr') -contains $_ } { Get-PackageReference -Package $package }
        { @('PackageVersion', 'pv') -contains $_ } { Get-PackageVersion -Package $package }
        { @('Version', 'v') -contains $_ } { Get-Version -Package $package }
    }
}
finally {
    if ($UseClipboard) {
        Set-Clipboard -Value $clipboard
    }
}
