using module ./software.psm1

[CmdletBinding(DefaultParameterSetName = 'Provider')]
param (
    [Parameter(ParameterSetName = 'Provider')]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Provider') {
            $validProviders = (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string] $Provider,

    [Parameter(ParameterSetName = 'Export')]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-export-ids.ps1")},
        ErrorMessage = 'Export not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Export') {
            $validExports = (& "$env:HOME/.local/bin/software/get-export-ids.ps1")
            $validExports -like "$wordToComplete*"
        }
    })]
    [string] $Export
)
begin {
    & "$env:HOME/.local/bin/env/begin-loading.ps1"
}
process {
    $upgrades = & $PSScriptRoot/get-exports.ps1 -Provider $Provider -Export $Export -Versioned |
        ForEach-Object {
            & $PSScriptRoot/get-export-script.ps1 -Id $_.Id.ToString() -Check
        } |
        ForEach-Object -Parallel {
            & $_
        }

    if ($upgrades.Length -gt 0) {
        $displayProperties = @(
            @{ Name = 'Provider'; Expression = { $_.Id.Provider }},
            @{ Name = 'Export'; Expression = { $_.Id.Export }},
            'Name',
            'Current',
            'Available'
        )
        $upgrades |
            Select-Object -Property $displayProperties |
            Sort-Object -Property Provider, Export, Name |
            Format-Table
    } else {
        Write-Output 'No upgrades found.'
    }

    & "$env:HOME/.local/bin/env/end-loading.ps1"
}
