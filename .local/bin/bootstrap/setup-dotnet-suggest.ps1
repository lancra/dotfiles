#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$fileName = '.dotnet-suggest-registration.txt'
$sourcePath = "$env:HOME/$fileName"
$sourceExists = Test-Path -Path $sourcePath
$isLink = & is-link.ps1 -Path $sourcePath -ErrorAction SilentlyContinue

if ($isLink) {
    Write-Output 'Links have already been established.'
    exit 0
}

$machineRootDirectory = & get-or-add-machine-directory.ps1 -Configuration
$machineDirectory = "$machineRootDirectory/dotnet"
New-Item -ItemType Directory -Path $machineDirectory -Force | Out-Null

$machinePath = "$machineDirectory/dotnet/$fileName"
if ($sourceExists) {
    Move-Item -Path $sourcePath -Destination $machinePath | Out-Null
} else {
    New-Item -ItemType File -Path $machinePath | Out-Null
}

$symlinkTarget = & resolve-relative-path.ps1 -Source $sourcePath -Target $machinePath
New-Item -ItemType SymbolicLink -Path $sourcePath -Target $symlinkTarget | Out-Null
Write-Output "Link established for .NET suggest."
