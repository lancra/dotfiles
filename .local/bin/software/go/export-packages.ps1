using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-packages.ps1 |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Name = $_.Name
            Module = $_.Module
        }

        [Installation]::new($id, $metadata)
    }
