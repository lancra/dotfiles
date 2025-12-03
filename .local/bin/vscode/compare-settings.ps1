[CmdletBinding()]
param(
    [switch] $Unsorted
)

$sourceSettingsPath = "$env:XDG_CONFIG_HOME/vscode/settings.json"
$settingsPath = $sourceSettingsPath
if (-not $Unsorted) {
    $settings = Get-Content -Path $settingsPath |
        ConvertFrom-Json

    $settingsPath = "$([System.IO.Path]::GetTempFileName()).json"
    & "$env:BIN/vscode/sort-settings-object.ps1" -Settings $settings |
        Set-Content -Path $settingsPath
}

$generatedPath = "$([System.IO.Path]::GetTempFileName()).json"

& "$env:BIN/vscode/generate-settings.ps1" -Path $generatedPath
git diff --no-index $generatedPath $settingsPath

Remove-Item -Path $generatedPath
if (-not $Unsorted) {
    Remove-Item -Path $settingsPath
}
