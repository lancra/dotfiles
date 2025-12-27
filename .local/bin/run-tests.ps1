#requires -Modules Pester

[CmdletBinding()]
param(
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

if ($Detailed) {
    $configuration.Output.Verbosity = 'Detailed'
}

Invoke-Pester -Configuration $configuration
