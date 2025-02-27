#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter()]
    [string] $Application = 'Visual Studio Code',

    [Parameter()]
    [string] $AppDataDirectory = 'Code',

    [Parameter()]
    [string] $DefaultConfigurationDirectory = '.vscode',

    [Parameter()]
    [string] $TrackedConfigurationDirectory = 'vscode'
)

function Write-SetupOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $InputObject
    )
    process {
        Write-Output "${TrackedConfigurationDirectory}: $InputObject"
    }
}

$argvFileName = 'argv.json'
$keybindingsFileName = 'keybindings.json'
$settingsFileName = 'settings.json'

$vsCodeUserDirectoryPath = "$env:APPDATA/$AppDataDirectory/User"

$argvSourcePath = "$env:HOME/$DefaultConfigurationDirectory/$argvFileName"
$keybindingsSourcePath = "$vsCodeUserDirectoryPath/$keybindingsFileName"
$settingsSourcePath = "$vsCodeUserDirectoryPath/$settingsFileName"

$sourcePaths = @($argvSourcePath, $keybindingsSourcePath, $settingsSourcePath)
$missingFiles = (Test-Path -Path $sourcePaths | Where-Object { -not $_ }).Length -ne 0

if ($missingFiles) {
    Write-SetupOutput "Install $Application before executing this script."
    exit 1
}

$linkChecks = @{}
$sourcePaths |
    ForEach-Object { $linkChecks[$_] = (is-link.ps1 -Path $_) }

$anyMissingLinks = ($linkChecks.GetEnumerator() |
    Where-Object { -not $_.Value }).Length -ne 0

if (-not $anyMissingLinks) {
    Write-SetupOutput 'Links have already been established.'
    exit 0
}

if (-not $linkChecks[$argvSourcePath]) {
    $machineRootDirectory = & "$env:HOME/.local/bin/env/get-or-add-machine-directory.ps1" -Configuration
    $argvTargetDirectoryPath = "$machineRootDirectory/$TrackedConfigurationDirectory"
    $argvTargetPath = "$argvTargetDirectoryPath/$argvFileName"

    $targetExists = Test-Path -Path $argvTargetPath
    if (-not $targetExists) {
        New-Item -ItemType Directory -Path $argvTargetDirectoryPath -Force | Out-Null
        Move-Item -Path $argvSourcePath -Destination $argvTargetPath | Out-Null
    } else {
        Remove-Item -Path $argvSourcePath | Out-Null
    }

    $symlinkTarget = resolve-relative-path.ps1 -Source $env:HOME/$DefaultConfigurationDirectory -Target $argvTargetPath
    New-Item -ItemType SymbolicLink -Path $argvSourcePath -Target $symlinkTarget | Out-Null

    Write-SetupOutput "Link established for $argvFileName."
}

$vsCodeConfigurationDirectoryPath = "$env:HOME/.config/$TrackedConfigurationDirectory"

if (-not $linkChecks[$keybindingsSourcePath]) {
    $keybindingsTargetPath = "$vsCodeConfigurationDirectoryPath/$keybindingsFileName"
    $keybindingsSymlinkTarget = resolve-relative-path.ps1 -Source $keybindingsSourcePath -Target $keybindingsTargetPath

    Remove-Item -Path $keybindingsSourcePath | Out-Null
    New-Item -ItemType SymbolicLink -Path $keybindingsSourcePath -Target $keybindingsSymlinkTarget | Out-Null

    Write-SetupOutput "Link established for $keybindingsFileName."
}

if (-not $linkChecks[$settingsSourcePath]) {
    $settingsTargetPath = "$vsCodeConfigurationDirectoryPath/$settingsFileName"
    $settingsSymlinkTarget = resolve-relative-path.ps1 -Source $settingsSourcePath -Target $settingsTargetPath

    Remove-Item -Path $settingsSourcePath | Out-Null
    New-Item -ItemType SymbolicLink -Path $settingsSourcePath -Target $settingsSymlinkTarget | Out-Null

    Write-SetupOutput "Link established for $settingsFileName."
}
