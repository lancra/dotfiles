#requires -Modules Pester

<#
.SYNOPSIS
Runs PowerShell script tests.

.DESCRIPTION
Defines the configuration required to run defined tests and invokes Pester.

.PARAMETER Path
The path to be searched for tests. When this value is not provided, the tests
root directory is used.

.PARAMETER Detailed
Specifies that the Detailed Pester output verbosity should be used.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path,

    [switch] $Detailed
)

$testsDirectory = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'tests'
$excludedPaths = Get-ChildItem -Path $testsDirectory -Recurse -Filter '.*.ps1' |
    Select-Object -ExpandProperty FullName

$configuration = New-PesterConfiguration
$configuration.Run.ExcludePath = $excludedPaths
$configuration.Run.Path = $testsDirectory
$configuration.Run.TestExtension = '.ps1'
$configuration.Should.ErrorAction = 'Continue'

if (-not [string]::IsNullOrEmpty($Path)) {
    $configuration.Run.Path = $Path
}

if ($Detailed) {
    $configuration.Output.Verbosity = 'Detailed'
}

Invoke-Pester -Configuration $configuration
