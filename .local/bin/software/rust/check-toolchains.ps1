using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-toolchains.ps1 |
    ForEach-Object {
        if ($_.Current -eq $_.Available) {
            return
        }

        $id = [InstallationId]::new($_.Id, $exportId)
        [InstallationUpgrade]::new($id, $_.Name, $_.Current, $_.Available)
    }
