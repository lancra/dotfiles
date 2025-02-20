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

class InstallationProvider {
    [string] $Id
    [InstallationExport[]] $Exports

    InstallationProvider([string] $id, [InstallationExport[]] $exports) {
        $this.Id = $id
        $this.Exports = $exports
    }
}

enum InstallationExportScope {
    Local
    Global
}

class InstallationExport {
    [InstallationExportId] $Id
    [string] $Name
    [InstallationExportScope] $Scope
    [bool] $Versioned

    InstallationExport([InstallationExportId] $id, [string] $name, [InstallationExportScope] $scope, [bool] $versioned) {
        $this.Id = $id
        $this.Name = $name ? $name : $id.Export
        $this.Scope = $scope
        $this.Versioned = $versioned
    }
}
