using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-crates.ps1 |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Name = $_.Name
            Description = $_.Description
        }

        [Installation]::new($id, $metadata)
    }
