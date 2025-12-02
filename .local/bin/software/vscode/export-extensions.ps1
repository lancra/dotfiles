using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

Get-Content -Path "$env:HOME/.vscode/extensions/extensions.json" |
    ConvertFrom-Json |
    ForEach-Object {
        $identifier = $_.identifier

        $directoryPath = $_.location.path.TrimStart('/')
        $manifestPath = Join-Path -Path $directoryPath -ChildPath '.vsixmanifest'
        $manifest = [xml](Get-Content -Path $manifestPath)
        $manifestMetadata = $manifest.PackageManifest.Metadata

        $id = [InstallationId]::new($identifier.id, $exportId)
        $metadata = [ordered]@{
            Uuid = $identifier.uuid
            DisplayName = $manifestMetadata.DisplayName
            Description = $manifestMetadata.Description.InnerText
        }

        [Installation]::new($id, $metadata)
    }
