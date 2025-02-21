using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

Get-InstalledModule |
    ForEach-Object {
        $latestModule = Find-Module -Name $_.Name -Repository $_.Repository
        if ($latestModule.Version -eq $_.Version) {
            return
        }

        $id = [InstallationId]::new($_.Name, $exportId)
        [InstallationUpgrade]::new($id, $_.Version, $latestModule.Version)
    }
