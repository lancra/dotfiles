#Requires -RunAsAdministrator

[CmdletBinding()]
param ()

function Write-SetupOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $InputObject
    )
    process {
        Write-Output "pwsh: $InputObject"
    }
}

$powerShellHostProfileFileName = 'Microsoft.PowerShell_profile.ps1'
$vsCodeHostProfileFileName = 'Microsoft.VSCode_profile.ps1'

$documentsPath = "$env:HOME/Documents"
$coreDocumentsDirectory = "$documentsPath/PowerShell"
$windowsDocumentsDirectory = "$documentsPath/WindowsPowerShell"

New-Item -ItemType Directory -Path $coreDocumentsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $windowsDocumentsDirectory -Force | Out-Null

$corePowerShellHostProfileSourcePath = "$coreDocumentsDirectory/$powerShellHostProfileFileName"
$coreVSCodeHostProfileSourcePath = "$coreDocumentsDirectory/$vsCodeHostProfileFileName"
$windowsPowerShellHostProfileSourcePath = "$windowsDocumentsDirectory/$powerShellHostProfileFileName"
$windowsVSCodeHostProfileSourcePath = "$windowsDocumentsDirectory/$vsCodeHostProfileFileName"

$sourcePaths = @(
    $corePowerShellHostProfileSourcePath,
    $coreVSCodeHostProfileSourcePath,
    $windowsPowerShellHostProfileSourcePath,
    $windowsVSCodeHostProfileSourcePath
)

$linkChecks = @{}
$sourcePaths |
    ForEach-Object {
        $pathExists = Test-Path -Path $_
        $isLink = $pathExists -and (& "$env:BIN/is-link.ps1" -Path $_)
        $linkChecks[$_] = $isLink
    }

$anyMissingLinks = ($linkChecks.GetEnumerator() |
    Where-Object { -not $_.Value }).Length -ne 0

if (-not $anyMissingLinks) {
    Write-SetupOutput 'Links have already been established.'
    exit 0
}

$configPath = "$env:XDG_CONFIG_HOME/powershell"
$corePowerShellHostConfigProfilePath = "$configPath/profile.core.powershell.ps1"
$coreVSCodeHostConfigProfilePath = "$configPath/profile.core.vscode.ps1"
$windowsPowerShellHostConfigProfilePath = "$configPath/profile.windows.powershell.ps1"
$windowsVSCodeHostConfigProfilePath = "$configPath/profile.windows.vscode.ps1"

$corePowerShellHostSymlinkTarget = resolve-relative-path-target.ps1 -Source $coreDocumentsDirectory -Target $corePowerShellHostConfigProfilePath
$coreVSCodeHostSymlinkTarget = resolve-relative-path-target.ps1 -Source $coreDocumentsDirectory -Target $coreVSCodeHostConfigProfilePath
$windowsPowerShellHostSymlinkTarget = resolve-relative-path-target.ps1 -Source $windowsDocumentsDirectory -Target $windowsPowerShellHostConfigProfilePath
$windowsVSCodeHostSymlinkTarget = resolve-relative-path-target.ps1 -Source $windowsDocumentsDirectory -Target $windowsVSCodeHostConfigProfilePath

if (-not $linkChecks[$corePowerShellHostProfileSourcePath]) {
    Remove-Item -Path $corePowerShellHostProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $corePowerShellHostProfileSourcePath -Target $corePowerShellHostSymlinkTarget | Out-Null

    Write-SetupOutput 'The profile link for the PowerShell host has been established for Core PowerShell.'
}

if (-not $linkChecks[$coreVSCodeHostProfileSourcePath]) {
    Remove-Item -Path $coreVSCodeHostProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $coreVSCodeHostProfileSourcePath -Target $coreVSCodeHostSymlinkTarget | Out-Null

    Write-SetupOutput 'The profile link for the VS Code host has been established for Core PowerShell.'
}

if (-not $linkChecks[$windowsPowerShellHostProfileSourcePath]) {
    Remove-Item -Path $windowsPowerShellHostProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $windowsPowerShellHostProfileSourcePath -Target $windowsPowerShellHostSymlinkTarget | Out-Null

    Write-SetupOutput 'The profile link for the PowerShell host has been established for Windows PowerShell.'
}

if (-not $linkChecks[$windowsVSCodeHostProfileSourcePath]) {
    Remove-Item -Path $windowsVSCodeHostProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $windowsVSCodeHostProfileSourcePath -Target $windowsVSCodeHostSymlinkTarget | Out-Null

    Write-SetupOutput 'The profile link for the VS Code host has been established for Windows PowerShell.'
}
