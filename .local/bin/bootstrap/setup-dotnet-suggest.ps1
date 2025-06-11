#Requires -RunAsAdministrator

[CmdletBinding()]
param()

function Write-SetupOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $InputObject
    )
    process {
        Write-Output "dotnet-suggest: $InputObject"
    }
}

$fileName = '.dotnet-suggest-registration.txt'
$sourcePath = "$env:HOME/$fileName"
$sourceExists = Test-Path -Path $sourcePath
$isLink = & is-link.ps1 -Path $sourcePath -ErrorAction SilentlyContinue

if ($isLink) {
    Write-SetupOutput 'Links have already been established.'
    exit 0
}

$machineRootDirectory = & "$env:HOME/.local/bin/env/get-or-add-machine-directory.ps1" -Configuration
$machineDirectory = "$machineRootDirectory/dotnet"
New-Item -ItemType Directory -Path $machineDirectory -Force | Out-Null

$machinePath = "$machineDirectory/$fileName"
$targetExists = Test-Path -Path $machinePath
if (-not $targetExists) {
    if ($sourceExists) {
        Move-Item -Path $sourcePath -Destination $machinePath | Out-Null
    } else {
        New-Item -ItemType File -Path $machinePath | Out-Null
    }
}

$symlinkTarget = & resolve-relative-path-target.ps1 -Source $env:HOME -Target $machinePath
New-Item -ItemType SymbolicLink -Path $sourcePath -Target $symlinkTarget | Out-Null
Write-SetupOutput "Link established for .NET suggest."
