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
        $registryDefinition = & "$PSScriptRoot/get-registry-definitions.ps1" -Uri $_.Registry
        if ($null -eq $registryDefinition) {
            Write-Warning "Unknown podman image registry '$($_.Registry)'."
            return
        }

        $getRemoteDigestsScriptName = $registryDefinition.DigestStorage -eq 'api' `
            ? "get-$($registryDefinition.ScriptName)-remote-digests" `
            : 'get-cached-remote-digests'

        $digestLookup = & "$PSScriptRoot/$getRemoteDigestsScriptName.ps1" -Image $_
        if ($digestLookup.Count -eq 0) {
            Write-Warning "No digests found for $($_.Id)."
            return
        }

        $latestDigest = $digestLookup['@latest']
        if ($_.Digest -eq $latestDigest) {
            return
        }

        $skipImage = $false
        $currentTag = $digestLookup[$_.Digest]
        if ($null -eq $currentTag) {
            $skipImage = $true
            Write-Host "$($PSStyle.Foreground.Red)Unable to find the current '$($_.Digest)' tag for $($_.Id).$($PSStyle.Reset)"
        }

        $latestTag = $digestLookup[$latestDigest]
        if ($null -eq $latestTag) {
            $skipImage = $true
            Write-Host "$($PSStyle.Foreground.Red)Unable to find the latest '$($latestDigest)' tag for $($_.Id).$($PSStyle.Reset)"
        }

        if ($skipImage) {
            return
        }

        $id = [InstallationId]::new($_.Id, $exportId)
        $current = Get-VersionTag -Tag ($digestLookup[$_.Digest])
        $available = Get-VersionTag -Tag ($digestLookup[$latestDigest])
        [InstallationUpgrade]::new($id, $id.Value, $current, $available)
    }
