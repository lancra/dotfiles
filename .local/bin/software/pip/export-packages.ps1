using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

$homepageGroupName = 'Homepage'
$packages = & pip list --not-required --format json --verbose |
    ConvertFrom-Json |
    ForEach-Object -Parallel {
        $metadataRelativePath = & pip show --files $_.name |
            Where-Object { $_ -match '.*.dist-info\\METADATA' } |
            ForEach-Object { $_.Trim() } |
            Select-Object -First 1
        $metadataPath = Join-Path -Path $_.location -ChildPath $metadataRelativePath

        $homepagePattern = "^Project-URL: Homepage, (?<$using:homepageGroupName>.*)|^Home-page: (?<$using:homepageGroupName>.*)"
        $homepageMatch = Select-String -Path $metadataPath -Pattern $homepagePattern
        $homepageMatchGroup = $homepageMatch.Matches.Groups | Where-Object -Property Name -EQ $using:homepageGroupName
        @{
            Id = $_.name
            Homepage = $homepageMatchGroup.Value
        }
    }

$packages |
    ForEach-Object {
        $id = [InstallationId]::new($_.Id, $exportId)
        $metadata = [ordered]@{
            Homepage = $_.Homepage
        }

        [Installation]::new($id, $metadata)
    }
