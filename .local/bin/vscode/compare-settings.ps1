[CmdletBinding()]
param()

$settingsPath = "$env:XDG_CONFIG_HOME/vscode/settings.json"
$generatedPath = "$([System.IO.Path]::GetTempFileName()).json"

& "$env:BIN/vscode/generate-settings.ps1" -Path $generatedPath
git diff --no-index $generatedPath $settingsPath
Remove-Item -Path $generatedPath
