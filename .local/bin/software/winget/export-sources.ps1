using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& winget source export |
    ForEach-Object {
        $source = $_ |
            ConvertFrom-Json

        $id = [InstallationId]::new($source.Identifier, $exportId)
        $metadata = [ordered]@{
            Name = $source.Name
            Url = $source.Arg
            Type = $source.Type
        }

        [Installation]::new($id, $metadata)
    }
