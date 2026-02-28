using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-extensions.ps1 |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Description = $_.Description
            Preview = $_.Preview
            Experimental = $_.Experimental
        }

        [Installation]::new($id, $metadata)
    }
