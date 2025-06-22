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
    [System.Management.Automation.SemanticVersion] $Version

    InstallationPin([InstallationId] $id, [System.Management.Automation.SemanticVersion] $version) {
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
