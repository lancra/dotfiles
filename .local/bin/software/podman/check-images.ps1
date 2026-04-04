using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

function Get-VersionTag {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Tag
    )
    process {
        $Tag |
            Where-Object { -not $_.Contains('latest') } |
            Sort-Object -Property Length -Descending |
            Select-Object -First 1
    }
}

& $PSScriptRoot/get-images.ps1 |
    ForEach-Object {
        $digestLookup = & "$PSScriptRoot/get-remote-digests.ps1" -Id $_.Id
        if ($digestLookup.Count -eq 0) {
            Write-Warning "No digests found for $($_.Id)."
            return
        }

        $latestDigest = $digestLookup['@latest']
        if ($_.Digest -eq $latestDigest) {
            return
        }

        $id = [InstallationId]::new($_.Id, $exportId)
        $current = Get-VersionTag -Tag ($digestLookup[$_.Digest])
        $available = Get-VersionTag -Tag ($digestLookup[$latestDigest])
        [InstallationUpgrade]::new($id, $id.Value, $current, $available)
    }
