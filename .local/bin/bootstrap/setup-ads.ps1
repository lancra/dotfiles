#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$setupParameters = @{
    Application = 'Azure Data Studio'
    AppDataDirectory = 'azuredatastudio'
    DefaultConfigurationDirectory = '.azuredatastudio'
    TrackedConfigurationDirectory = 'ads'
}
& $env:HOME/.local/bin/links/setup-vscode.ps1 @setupParameters
