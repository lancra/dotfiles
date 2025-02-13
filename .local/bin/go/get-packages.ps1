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
        $name = [System.IO.Path]::GetFileNameWithoutExtension($metadataSegments[0])

        $pathSegments = $packageLines[1] -split "`t" | Where-Object { $_ -ne '' }
        $path = $pathSegments[1]

        $moduleSegments = $packageLines[2] -split "`t" | Where-Object { $_ -ne '' }
        $module = $moduleSegments[1]
        $version = $moduleSegments[2]

        @{
            Id = $path
            Name = $name
            Module = $module
            Version = $version
        }
    } |
    Sort-Object -Property Name
