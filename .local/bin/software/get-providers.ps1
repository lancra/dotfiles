using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter()]
    [string] $Provider
)

$providers = Get-Content -Path "$env:XDG_CONFIG_HOME/software/providers.json" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty providers |
    ForEach-Object {
        $providerId = $_.id
        $exports = $_.exports |
            ForEach-Object {
                $id = [InstallationExportId]::new($_.id, $providerId)
                $scope = [InstallationExportScope]$_.scope
                [InstallationExport]::new($id, $_.name, $scope, $_.versioned)
            }

        [InstallationProvider]::new($providerId, $exports)
    }

if ($Provider) {
    $providers = $providers |
        Where-Object -Property Id -EQ $Provider
}

$providers
