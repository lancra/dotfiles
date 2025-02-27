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

$defaultProfileFileName = 'Microsoft.PowerShell_profile.ps1'
$vsCodeProfileFileName = 'Microsoft.VSCode_profile.ps1'

$documentsPath = "$env:HOME/Documents"
$coreDocumentsDirectory = "$documentsPath/PowerShell"
$windowsDocumentsDirectory = "$documentsPath/WindowsPowerShell"

New-Item -ItemType Directory -Path $coreDocumentsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $windowsDocumentsDirectory -Force | Out-Null

$coreDefaultProfileSourcePath = "$coreDocumentsDirectory/$defaultProfileFileName"
$coreVSCodeProfileSourcePath = "$coreDocumentsDirectory/$vsCodeProfileFileName"
$windowsDefaultProfileSourcePath = "$windowsDocumentsDirectory/$defaultProfileFileName"
$windowsVSCodeProfileSourcePath = "$windowsDocumentsDirectory/$vsCodeProfileFileName"

$sourcePaths = @(
    $coreDefaultProfileSourcePath,
    $coreVSCodeProfileSourcePath,
    $windowsDefaultProfileSourcePath,
    $windowsVSCodeProfileSourcePath
)

$linkChecks = @{}
$sourcePaths |
    ForEach-Object {
        $pathExists = Test-Path -Path $_
        $isLink = $pathExists -and (is-link.ps1 -Path $_)
        $linkChecks[$_] = $isLink
    }

$anyMissingLinks = ($linkChecks.GetEnumerator() |
    Where-Object { -not $_.Value }).Length -ne 0

if (-not $anyMissingLinks) {
    Write-SetupOutput 'Links have already been established.'
}

$configPath = "$env:XDG_CONFIG_HOME/powershell"
$coreConfigProfilePath = "$configPath/core.profile.ps1"
$windowsConfigProfilePath = "$configPath/windows.profile.ps1"

$coreSymlinkTarget = resolve-relative-path.ps1 -Source $coreDocumentsDirectory -Target $coreConfigProfilePath
$windowsSymlinkTarget = resolve-relative-path.ps1 -Source $windowsDocumentsDirectory -Target $windowsConfigProfilePath

if (-not $linkChecks[$coreDefaultProfileSourcePath]) {
    Remove-Item -Path $coreDefaultProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $coreDefaultProfileSourcePath -Target $coreSymlinkTarget | Out-Null

    Write-SetupOutput 'Link established for default Core profile.'
}

if (-not $linkChecks[$coreVSCodeProfileSourcePath]) {
    Remove-Item -Path $coreVSCodeProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $coreVSCodeProfileSourcePath -Target $coreSymlinkTarget | Out-Null

    Write-SetupOutput 'Link established for VS Code Core profile.'
}

if (-not $linkChecks[$windowsDefaultProfileSourcePath]) {
    Remove-Item -Path $windowsDefaultProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $windowsDefaultProfileSourcePath -Target $windowsSymlinkTarget | Out-Null

    Write-SetupOutput 'Link established for default Windows profile.'
}

if (-not $linkChecks[$windowsVSCodeProfileSourcePath]) {
    Remove-Item -Path $windowsVSCodeProfileSourcePath -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $windowsVSCodeProfileSourcePath -Target $windowsSymlinkTarget | Out-Null

    Write-SetupOutput 'Link established for VS Code Windows profile.'
}
