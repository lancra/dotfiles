using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& dotnet-tools-outdated --format json --noIndent --outPkgRegardlessState |
    ConvertFrom-Json |
    Select-Object -ExpandProperty dotnet-tools-outdated |
    ForEach-Object {
        if ($_.currentVer -eq $_.availableVer) {
            return
        }

        $id = [InstallationId]::new($_.packageName, $exportId)
        [InstallationUpgrade]::new($id, $_.currentVer, $_.availableVer)
    }
