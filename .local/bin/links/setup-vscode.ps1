#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$argvFileName = 'argv.json'
$keybindingsFileName = 'keybindings.json'
$settingsFileName = 'settings.json'

$vsCodeUserDirectoryPath = "$env:APPDATA/Code/User"

$argvSourcePath = "$env:HOME/.vscode/$argvFileName"
$keybindingsSourcePath = "$vsCodeUserDirectoryPath/$keybindingsFileName"
$settingsSourcePath = "$vsCodeUserDirectoryPath/$settingsFileName"

$sourcePaths = @($argvSourcePath, $keybindingsSourcePath, $settingsSourcePath)
$missingFiles = (Test-Path -Path $sourcePaths | Where-Object { -not $_ }).Length -ne 0

if ($missingFiles) {
    Write-Output 'Install Visual Studio Code before executing this script.'
    exit 1
}

$linkChecks = @{}
$sourcePaths |
    ForEach-Object { $linkChecks[$_] = (is-link.ps1 -Path $_) }

$anyMissingLinks = ($linkChecks.GetEnumerator() |
    Where-Object { -not $_.Value }).Length -ne 0

if (-not $anyMissingLinks) {
    Write-Output 'Links have already been established.'
    exit 0
}

if (-not $linkChecks[$argvSourcePath]) {
    $machine = $env:COMPUTERNAME.ToLower()
    $argvTargetDirectoryPath = "$env:HOME/.config/machine/$machine/vscode"
    $argvTargetPath = "$argvTargetDirectoryPath/$argvFileName"

    New-Item -ItemType Directory -Path $argvTargetDirectoryPath -Force | Out-Null
    Move-Item -Path $argvSourcePath -Destination $argvTargetPath | Out-Null
    New-Item -ItemType SymbolicLink -Path $argvSourcePath -Target $argvTargetPath | Out-Null

    Write-Output "Link established for $argvFileName."
}

$vsCodeConfigurationDirectoryPath = "$env:HOME/.config/vscode"

if (-not $linkChecks[$keybindingsSourcePath]) {
    $keybindingsTargetPath = "$vsCodeConfigurationDirectoryPath/$keybindingsFileName"
    $keybindingsSymlinkTarget = resolve-relative-path.ps1 -Source $keybindingsSourcePath -Target $keybindingsTargetPath

    Remove-Item -Path $keybindingsSourcePath | Out-Null
    New-Item -ItemType SymbolicLink -Path $keybindingsSourcePath -Target $keybindingsSymlinkTarget | Out-Null

    Write-Output "Link established for $keybindingsFileName."
}

if (-not $linkChecks[$settingsSourcePath]) {
    $settingsTargetPath = "$vsCodeConfigurationDirectoryPath/$settingsFileName"
    $settingsSymlinkTarget = resolve-relative-path.ps1 -Source $settingsSourcePath -Target $settingsTargetPath

    Remove-Item -Path $settingsSourcePath | Out-Null
    New-Item -ItemType SymbolicLink -Path $settingsSourcePath -Target $settingsSymlinkTarget | Out-Null

    Write-Output "Link established for $settingsFileName."
}
