#Requires -Modules powershell-yaml

<#
.SYNOPSIS
Counts the installation definitions and machine locations by provider export.

.DESCRIPTION
Using the locations per unique installation, represents the definition and
machine location count for each software provider export.

.PARAMETER Provider
The optional software provider to count. If this parameter is not provided, all
providers are counted.

.PARAMETER Export
The optional software provider export to count. If this parameter is not
provided, all provider exports are counted.
#>

using module ./software.psm1

[CmdletBinding(DefaultParameterSetName = 'Provider')]
param(
    [Parameter(ParameterSetName = 'Provider', Position = 0)]
    [ValidateScript({
        $_ -in (& "$env:BIN/software/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Provider') {
            $validProviders = (& "$env:BIN/software/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string[]] $Provider,

    [Parameter(ParameterSetName = 'Export')]
    [ValidateScript({
        $_ -in (& "$env:BIN/software/get-export-ids.ps1")},
        ErrorMessage = 'Export not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Export') {
            $validExports = (& "$env:BIN/software/get-export-ids.ps1")
            $validExports -like "$wordToComplete*"
        }
    })]
    [string[]] $Export
)

$machinePropertyLookup = [ordered]@{}
& $env:BIN/env/get-machines.ps1 |
    ForEach-Object {
        $machinePropertyLookup[$_] = "$($_.Substring(0, 1).ToUpper())$($_.Substring(1, $_.Length - 1))"
    }

$counts = @{}

& $PSScriptRoot/get-installation-locations.ps1 -Provider $Provider -Export $Export |
    ForEach-Object {
        $key = "$($_.Id.Provider).$($_.Id.Export)"
        if (-not $counts.ContainsKey($key)) {
            $count = [PSCustomObject]@{
                Provider = $_.Id.Provider
                Export = $_.Id.Export
                Definitions = 0
            }

            $machinePropertyLookup.GetEnumerator() |
                Select-Object -ExpandProperty Value |
                ForEach-Object {
                    $count | Add-Member -MemberType NoteProperty -Name $_ -Value 0
                }

            $counts[$key] = $count
        }

        $counts[$key].Definitions += 1
        $_.Machines |
            ForEach-Object {
                $machineKey = $machinePropertyLookup[$_]
                $counts[$key].$machineKey += 1
            }
    }

$counts.GetEnumerator() |
    Select-Object -ExpandProperty Value |
    Sort-Object -Property Provider, Export
