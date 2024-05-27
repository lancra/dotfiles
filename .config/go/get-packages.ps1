[CmdletBinding()]
param()

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

@($lines -join '\n' -split '(?:\\n){2,}') |
    ForEach-Object {
        $packageLines = $_ -split '\\n' | Where-Object { $_ -ne '' }

        $metadataSegments = $packageLines[0] -split ': '
        $id = [System.IO.Path]::GetFileNameWithoutExtension($metadataSegments[0])

        $pathSegments = $packageLines[2] -split "`t" | Where-Object { $_ -ne '' }
        $path = $pathSegments[1]
        $version = $pathSegments[2]

        @{
            Id = $id
            Path = $path
            Version = $version
        }
    } |
    Sort-Object -Property Id
