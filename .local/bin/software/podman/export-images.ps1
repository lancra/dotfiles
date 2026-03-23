using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-images.ps1 |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Architecture = $_.Architecture
            OperatingSystem = $_.OperatingSystem
        }

        [Installation]::new($id, $metadata)
    }
