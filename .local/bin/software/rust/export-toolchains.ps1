using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-toolchains.ps1 |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Name = $_.Name
            Channel = $_.Channel
            Environment = $_.Environment
        }

        [Installation]::new($id, $metadata)
    }
