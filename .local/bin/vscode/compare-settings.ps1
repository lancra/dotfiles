[CmdletBinding()]
param(
    [switch] $Unsorted
)

$timestamp = [datetime]::Now.ToString('HHmmss')
function New-TemporarySettingsPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )
    process {
        $temporaryDirectory = [System.IO.Path]::GetTempPath()
        $fileName = "$Name-vscode-settings.$timestamp.json"
        $path = Join-Path -Path $temporaryDirectory -ChildPath $fileName
        $path -replace '\\', '/'
    }
}

$sourceSettingsPath = "$env:XDG_CONFIG_HOME/vscode/settings.json"
$livePath = $sourceSettingsPath
if (-not $Unsorted) {
    $settings = Get-Content -Path $livePath |
        ConvertFrom-Json

    $livePath = New-TemporarySettingsPath -Name 'live'
    & "$env:BIN/vscode/sort-settings-object.ps1" -Settings $settings |
        Set-Content -Path $livePath
}

$generatedPath = New-TemporarySettingsPath -Name 'generated'

& "$env:BIN/vscode/generate-settings.ps1" -Path $generatedPath
git diff --no-index $generatedPath $livePath

Remove-Item -Path $generatedPath
if (-not $Unsorted) {
    Remove-Item -Path $livePath
}
