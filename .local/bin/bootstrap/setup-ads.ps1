#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$setupParameters = @{
    Application = 'Azure Data Studio'
    AppDataDirectory = 'azuredatastudio'
    DefaultConfigurationDirectory = '.azuredatastudio'
    TrackedConfigurationDirectory = 'ads'
}
& $PSScriptRoot/setup-vscode.ps1 @setupParameters
