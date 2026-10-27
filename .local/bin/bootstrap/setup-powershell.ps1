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
$allHostsProfileFileName = 'profile.ps1'

$documentsPath = "$env:HOME/Documents"
$coreDocumentsDirectory = "$documentsPath/PowerShell"
$windowsDocumentsDirectory = "$documentsPath/WindowsPowerShell"

New-Item -ItemType Directory -Path $coreDocumentsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $windowsDocumentsDirectory -Force | Out-Null

$configPath = "$env:XDG_CONFIG_HOME/powershell"

class ProfileLink {
    [string] $ProductDisplay
    [string] $HostDisplay
    [string] $Source
    [string] $Target

    ProfileLink([string] $productDisplay, [string] $hostDisplay, [string] $source, [string] $target) {
        $this.ProductDisplay = $productDisplay
        $this.HostDisplay = $hostDisplay
        $this.Source = $source
        $this.Target = $target
    }
}

$profileLinks = @(
    [ProfileLink]::new(
        'Core',
        'PowerShell',
        "$coreDocumentsDirectory/$powerShellHostProfileFileName",
        (& resolve-relative-path-target.ps1 -Source $coreDocumentsDirectory -Target "$configPath/profile.core.powershell.ps1")),
    [ProfileLink]::new(
        'Core',
        'VS Code',
        "$coreDocumentsDirectory/$vsCodeHostProfileFileName",
        (& resolve-relative-path-target.ps1 -Source $coreDocumentsDirectory -Target "$configPath/profile.core.vscode.ps1")),
    [ProfileLink]::new(
        'Core',
        '',
        "$coreDocumentsDirectory/$allHostsProfileFileName",
        (& resolve-relative-path-target.ps1 -Source $coreDocumentsDirectory -Target "$configPath/profile.core.ps1")),
    [ProfileLink]::new(
        'Windows',
        'PowerShell',
        "$windowsDocumentsDirectory/$powerShellHostProfileFileName",
        (& resolve-relative-path-target.ps1 -Source $windowsDocumentsDirectory -Target "$configPath/profile.windows.powershell.ps1")),
    [ProfileLink]::new(
        'Windows',
        'VS Code',
        "$windowsDocumentsDirectory/$vsCodeHostProfileFileName",
        (& resolve-relative-path-target.ps1 -Source $windowsDocumentsDirectory -Target "$configPath/profile.windows.vscode.ps1")),
    [ProfileLink]::new(
        'Windows',
        '',
        "$windowsDocumentsDirectory/$allHostsProfileFileName",
        (& resolve-relative-path-target.ps1 -Source $windowsDocumentsDirectory -Target "$configPath/profile.windows.ps1"))
)

$staleLinks = @($profileLinks |
    ForEach-Object {
        $pathExists = Test-Path -Path $_.Source
        if (-not $pathExists) {
            return $_
        }

        $isLink = & "$env:BIN/is-link.ps1" -Path $_.Source
        if (-not $isLink) {
            return $_
        }

        $linkTarget = (Get-Item -Path $_.Source |
            Select-Object -ExpandProperty Target) -replace '\\', '/'
        if ($linkTarget -ne $_.Target) {
            return $_
        }

        return $null
    } |
    Where-Object { $null -ne $_ })

if ($staleLinks.Length -eq 0) {
    Write-SetupOutput 'Links have already been established.'
    exit 0
}

$staleLinks |
    ForEach-Object {
        Remove-Item -Path $_.Source -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType SymbolicLink -Path $_.Source -Target $_.Target | Out-Null

        $hostDisplay = $_.HostDisplay ? "the $($_.HostDisplay) host" : 'all hosts'
        $productDisplay = $_.ProductDisplay
        Write-SetupOutput "The profile link for $hostDisplay has been established for $productDisplay PowerShell."
    }
