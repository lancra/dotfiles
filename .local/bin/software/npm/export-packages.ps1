using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

$packages = (& npm list --location=global --json |
    & jq --raw-output '.dependencies | keys[]' |
    ForEach-Object -Parallel {
        $homepage = & npm view --json $_ |
            & jq --raw-output '.homepage'

        @{
            Id = $_
            Homepage = $homepage
        }
    }) 2> $null

$packages |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Homepage = $_.Homepage
        }

        [Installation]::new($id, $metadata)
    }

