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
