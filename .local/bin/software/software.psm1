class InstallationExportId {
    [string] $Export
    [string] $Provider

    InstallationExportId([string] $export, [string] $provider) {
        $this.Export = $export
        $this.Provider = $provider
    }

    [string] ToString() {
        return "$($this.Provider).$($this.Export)"
    }
}

class InstallationId {
    [string] $Value
    [string] $Export
    [string] $Provider

    InstallationId([string] $value, [InstallationExportId] $exportId) {
        $this.Value = $value
        $this.Export = $exportId.Export
        $this.Provider = $exportId.Provider
    }

    [bool] Equals($other) {
        return $other -is [InstallationId] -and
            $this.Value -eq $other.Value -and
            $this.Export -eq $other.Export -and
            $this.Provider -eq $other.Provider
    }

    [string] ToString() {
        return "$($this.Provider).$($this.Export).$($this.Value)"
    }

    [int] GetHashCode() {
        return $this.ToString().GetHashCode()
    }
}

class Installation {
    [InstallationId] $Id
    [System.Collections.IDictionary] $Metadata

    Installation([InstallationId] $id, [System.Collections.IDictionary] $metadata) {
        $this.Id = $id
        $this.Metadata = $metadata
    }
}

class InstallationUpgrade {
    [InstallationId] $Id
    [string] $Name
    [string] $Current
    [string] $Available

    InstallationUpgrade([InstallationId] $id, [string] $current, [string] $available) {
        $this.Id = $id
        $this.Name = $id
        $this.Current = $current
        $this.Available = $available
    }

    InstallationUpgrade([InstallationId] $id, [string] $name, [string] $current, [string] $available) {
        $this.Id = $id
        $this.Name = $name
        $this.Current = $current
        $this.Available = $available
    }
}

class InstallationPin {
    [InstallationId] $Id
    [InstallationVersion] $Version

    InstallationPin([InstallationId] $id, [InstallationVersion] $version) {
        $this.Id = $id
        $this.Version = $version
    }
}

class InstallationProvider {
    [string] $Id
    [InstallationExport[]] $Exports

    InstallationProvider([string] $id, [InstallationExport[]] $exports) {
        $this.Id = $id
        $this.Exports = $exports
    }
}

class InstallationExport {
    [InstallationExportId] $Id
    [string] $Name
    [bool] $Versioned
    [bool] $Upsert

    InstallationExport(
        [InstallationExportId] $id,
        [string] $name,
        [bool] $versioned,
        [bool] $upsert
    ) {
        $this.Id = $id
        $this.Name = $name ? $name : $id.Export
        $this.Versioned = $versioned
        $this.Upsert = $upsert
    }
}

class InstallationLocation {
    [InstallationId] $Id
    [string[]] $Machines

    InstallationLocation([InstallationId] $id, [string[]] $machines) {
        $this.Id = $id
        $this.Machines = $machines
    }
}

class InstallationVersion : System.IComparable, System.IEquatable[object] {
    [int[]] $Release
    [string[]] $Prerelease

    InstallationVersion([string] $version) {
        $groupSeparatorIndex = $version.IndexOf('-')
        if ($groupSeparatorIndex -ne -1) {
            $releaseGroupText = $version.Substring(0, $groupSeparatorIndex)

            $prereleaseGroupText = $version.Substring($groupSeparatorIndex + 1)
            $this.Prerelease = -not [string]::IsNullOrEmpty($prereleaseGroupText) `
                ? @($prereleaseGroupText.Split('.')) `
                : @()
        } else {
            $releaseGroupText = $version
            $this.Prerelease = @()
        }

        $this.Release = -not [string]::IsNullOrEmpty($releaseGroupText) `
            ? @($releaseGroupText.Split('.') | ForEach-Object { [int]::Parse($_) }) `
            : @()
    }

    [int] CompareTo($other) {
        if (-not ($other -is [InstallationVersion])) {
            throw "Unable to compare InstallationVersion to $($other.GetType())."
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

        $maxPrereleaseSegments = [int]::Max($this.Release.Length, $other.Release.Length)
        for ($i = 0; $i -lt $maxPrereleaseSegments; $i++) {
            if ($i -gt ($this.Prerelease.Length - 1)) {
                return -1
            }

            if ($i -gt ($other.Prerelease.Length - 1)) {
                return 1
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

    [bool] Equals($other) {
        if (-not ($other -is [InstallationVersion])) {
            return $false
        }

        if ($this.Release.Length -ne $other.Release.Length -or
            $this.Prerelease.Length -ne $other.Prerelease.Length) {
            return $false
        }

        for ($i = 0; $i -lt $this.Release.Length; $i++) {
            if ($this.Release[$i] -ne $other.Release[$i]) {
                return $false
            }
        }

        for ($i = 0; $i -lt $this.Prerelease.Length; $i++) {
            if ($this.Prerelease[$i] -ne $other.Prerelease[$i]) {
                return $false
            }
        }

        return $true
    }
}
