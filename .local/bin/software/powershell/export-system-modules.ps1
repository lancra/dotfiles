using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-modules.ps1 -Scope 'Machine' |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Shell = $_.Shell
            Locations = $_.Locations
        }

        [Installation]::new($id, $metadata)
    }
