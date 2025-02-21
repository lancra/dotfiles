using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

(& npm outdated -g --json |
    & jq 'to_entries | map({id: .key, current: .value.current, available: .value.latest})' |
    ConvertFrom-Json |
    ForEach-Object {
        $id = [InstallationId]::new($_.id, $exportId)
        [InstallationUpgrade]::new($id, $_.current, $_.available)
    }) 2> $null
