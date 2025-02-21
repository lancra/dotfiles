using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

& pip list --not-required --outdated --format json |
    ConvertFrom-Json |
    ForEach-Object {
        $id = [InstallationId]::new($_.name, $exportId)
        [InstallationUpgrade]::new($id, $_.version, $_.latest_version)
    }
