#Requires -RunAsAdministrator

[CmdletBinding()]
param()

Get-ChildItem -Path $PSScriptRoot -Filter 'setup-*.ps1' |
    ForEach-Object {
        & $_
    }
