using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

$compressionExecutable = 'mozlz4-win64'
$compressionCommand = Get-Command -Name $compressionExecutable -ErrorAction SilentlyContinue
if (-not $compressionCommand) {
    $downloadCommand = 'gh release download --repo jusw85/mozlz4 --pattern mozlz4-win64.exe --dir "$env:USERPROFILE\OneDrive\Tools"'
    $message = "The $compressionExecutable executable used for Mozilla data compression is unavailable. " + `
        "Install it by executing ``$downloadCommand``"
    Write-Error -Message $message
}

function Get-DefaultProfileDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Directory
        )
    process {
        $lines = Get-Content -Path "$Directory/profiles.ini"
        for ($i = 0; $i -lt $lines.Length; $i++) {
            $line = $lines[$i]
            if (-not ($line.StartsWith('[Install'))) {
                continue
            }

            $prefix = 'Default='
            for ($j = $i + 1; $j -lt $lines.Length; $j++) {
                $line = $lines[$j]
                if (-not ($line.StartsWith($prefix))) {
                    continue
                }

                $relativePath = $line.TrimStart($prefix)
                return "$Directory/$relativePath"
            }
        }
    }
}

$profileDirectory = Get-DefaultProfileDirectory -Directory "$env:APPDATA/Mozilla/Firefox"
$sourcePath = "$profileDirectory/search.json.mozlz4"

$targetFileName = "firefox-search-engines.$(Get-Date -Format 'yyyyMMddHHmmss').json"
$targetPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $targetFileName

try {
    & $compressionExecutable $sourcePath $targetPath
    Get-Content -Path $targetPath |
        ConvertFrom-Json |
        Select-Object -ExpandProperty 'engines' |
        Where-Object -Property '_isConfigEngine' -EQ $null |
        ForEach-Object {
            $keyword = $_._definedAliases[0]
            $alias = $_._metaData.alias
            if ($null -eq $keyword) {
                $keyword = $alias
                $alias = $null
            }

            $id = [InstallationId]::new($keyword, $exportId)
            $metadata = [ordered]@{
                Name = $_._name
                Uri = $_._urls[0].template
                Guid = $_.id
            }

            if ($alias) {
                $metadata['Alias'] = $alias
            }

            [Installation]::new($id, $metadata)
        } |
        Sort-Object -Property Id
}
finally {
    Remove-Item -Path $targetPath -ErrorAction SilentlyContinue |
        Out-Null
}
