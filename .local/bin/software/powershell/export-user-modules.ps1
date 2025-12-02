using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-modules.ps1 -Scope 'User' |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Shell = $_.Shell
            Locations = $_.Locations
        }

        [Installation]::new($id, $metadata)
    }
