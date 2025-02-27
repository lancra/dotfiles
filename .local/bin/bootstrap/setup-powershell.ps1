[CmdletBinding()]
param ()

$configPath = "$env:XDG_CONFIG_HOME/powershell"
$documentsPath = "$env:HOME/Documents"

$defaultProfileFileName = 'Microsoft.PowerShell_profile.ps1'
$codeProfileFileName = 'Microsoft.VSCode_profile.ps1'

$coreConfigProfilePath = "$configPath/core.profile.ps1"
$coreDocumentsDirectory = "$documentsPath/PowerShell"
New-Item -ItemType Directory -Path $coreDocumentsDirectory -Force | Out-Null

$coreDefaultProfilePath = "$coreDocumentsDirectory/$defaultProfileFileName"
if (-not (Test-Path -Path $coreDefaultProfilePath)) {
    New-Item -ItemType SymbolicLink -Path $coreDefaultProfilePath -Target $coreConfigProfilePath
}

$coreCodeProfilePath = "$coreDocumentsDirectory/$codeProfileFileName"
if (-not (Test-Path -Path $coreCodeProfilePath)) {
    New-Item -ItemType SymbolicLink -Path $coreCodeProfilePath -Target $coreConfigProfilePath
}

$windowsConfigProfilePath = "$configPath/windows.profile.ps1"
$windowsDocumentsDirectory = "$documentsPath/WindowsPowerShell"
New-Item -ItemType Directory -Path $windowsDocumentsDirectory -Force | Out-Null

$windowsDefaultProfilePath = "$windowsDocumentsDirectory/$defaultProfileFileName"
if (-not (Test-Path -Path $windowsDefaultProfilePath)) {
    New-Item -ItemType SymbolicLink -Path $windowsDefaultProfilePath -Target $windowsConfigProfilePath
}

$windowsCodeProfilePath = "$windowsDocumentsDirectory/$codeProfileFileName"
if (-not (Test-Path -Path $windowsCodeProfilePath)) {
    New-Item -ItemType SymbolicLink -Path $windowsCodeProfilePath -Target $windowsConfigProfilePath
}
