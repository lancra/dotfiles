using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"
$persistedCrates = & "$env:HOME/.local/bin/software/get-installation-definitions.ps1" -Export $exportId

$inMemoryProperties = @('Id', 'Name', 'Description')
& $PSScriptRoot/get-crates.ps1 |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)

        $metadata = [ordered]@{
            Name = $_.Name
            Description = $_.Description
        }

        $persistedCrate = $persistedCrates |
            Where-Object -Property Id -EQ $_.Id
        if ($persistedCrate) {
            $persistedCrate.PSObject.Properties |
                Where-Object { -not $inMemoryProperties.Contains($_) } |
                ForEach-Object {
                    $metadata[$_.Name] = $_.Value
                }
        }

        [Installation]::new($id, $metadata)
    }
