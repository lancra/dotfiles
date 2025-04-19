using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

& rustup component list |
    ForEach-Object {
        $segments = $_.Split(' ')
        if ($segments.Length -eq 1) {
            return
        }

        $id = [InstallationId]::new($segments[0], $exportId)
        $metadata = [ordered]@{}

        [Installation]::new($id, $metadata)
    }
