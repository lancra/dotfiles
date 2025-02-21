using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

& $PSScriptRoot/get-packages.ps1 |
    ForEach-Object {
        $module = "$($_.Module)@latest"
        $newVersion = & go list -m -f "{{.Version}}" $module
        if ($_.Version -eq $newVersion) {
            return
        }

        $id = [InstallationId]::new($_.Id, $exportId)
        [InstallationUpgrade]::new($id, $_.Name, $_.Version.TrimStart('v'), $newVersion.TrimStart('v'))
    }
