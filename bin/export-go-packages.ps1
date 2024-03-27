[CmdletBinding(SupportsShouldProcess)]
param ()

$lines = @()
$foundFirstPackage = $false
& go version -m $env:GOPATH/bin |
    ForEach-Object {
        if ($_[0] -ne "`t") {
            if ($foundFirstPackage) {
                $lines += ''
            } else {
                $foundFirstPackage = $true
            }
        }

        $lines += $_
    }

$directoryPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'go'
New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

$packagesPath = Join-Path $directoryPath -ChildPath 'packages.csv'
@($lines -join '\n' -split '(?:\\n){2,}') |
    ForEach-Object {
        $packageLines = $_ -split '\\n' | Where-Object { $_ -ne '' }

        $metadataSegments = $packageLines[0] -split ': '
        $id = [System.IO.Path]::GetFileNameWithoutExtension($metadataSegments[0])

        $pathSegments = $packageLines[1] -split "`t" | Where-Object { $_ -ne '' }
        $path = $pathSegments[1]

        [ordered]@{
            Id = $id
            Path = $path
        }
    } |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $packagesPath
