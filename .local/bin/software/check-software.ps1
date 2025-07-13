<#
.SYNOPSIS
Checks for outdated software and facilitates upgrades if found.

.DESCRIPTION
Filters the target software exports by provided values, then executes a version
check for all matching installations, excluding matches with a pinned version
specified. Any outdated installations found are identified as automated or
manual for upgrades, and shown to the user along with a confirmation prompt.
When the prompt is confirmed, each installation is individually upgraded. If the
Refresh prompt option is selected, the upgrades are performed after a re-check
on all relevant providers. If any upgrades were performed, the relevant
providers are exported to machine state along with the environment variables.

.PARAMETER Provider
The optional software provider to check. If this parameter is not provided, all
providers are checked.

.PARAMETER Export
The optional software provider export to check. If this parameter is not
provided, all provider exports are checked.

.PARAMETER Show
Specifies that outdated software should be shown only, skipping the user prompt
for upgrading.

.PARAMETER DryRun
Specifies to iterate through the software upgrades without executing them.
#>

using module ./software.psm1

[CmdletBinding(DefaultParameterSetName = 'Provider')]
param (
    [Parameter(ParameterSetName = 'Provider', Position = 0)]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Provider') {
            $validProviders = (& "$env:HOME/.local/bin/software/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string[]] $Provider,

    [Parameter(ParameterSetName = 'Export')]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/software/get-export-ids.ps1")},
        ErrorMessage = 'Export not found.')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        if ($parameterName -eq 'Export') {
            $validExports = (& "$env:HOME/.local/bin/software/get-export-ids.ps1")
            $validExports -like "$wordToComplete*"
        }
    })]
    [string[]] $Export,

    [switch] $Show,

    [switch] $DryRun
)
begin {
    & "$env:HOME/.local/bin/env/begin-loading.ps1"

    function Get-InstallationPins {
        [CmdletBinding()]
        [OutputType([InstallationPin[]])]
        param()
        begin {
            $path = "$env:XDG_DATA_HOME/software/pins.csv"
        }
        process {
            if (-not (Test-Path -Path $path)) {
                return @()
            }

            Get-Content -Path $path |
                ConvertFrom-Csv |
                ForEach-Object {
                    $exportId = [InstallationExportId]::new($_.Export, $_.Provider)
                    $id = [InstallationId]::new($_.Id, $exportId)
                    $version = -not [string]::IsNullOrEmpty($_.Version) ? [InstallationVersion]::new($_.Version) : $null
                    [InstallationPin]::new($id, $version)
                }
        }
    }

    function Get-InstallationIds {
        [CmdletBinding()]
        [OutputType([InstallationId[]])]
        param(
            [Parameter(Mandatory)]
            [string] $FileName
        )
        begin {
            $path = "$env:XDG_DATA_HOME/software/$FileName.csv"
        }
        process {
            if (-not (Test-Path -Path $path)) {
                return @()
            }

            Get-Content -Path $path |
                ConvertFrom-Csv |
                ForEach-Object {
                    $exportId = [InstallationExportId]::new($_.Export, $_.Provider)
                    [InstallationId]::new($_.Id, $exportId)
                }
        }
    }

    function Get-Upgrades {
        [CmdletBinding()]
        [OutputType([InstallationUpgrade[]])]
        param(
            [Parameter(Mandatory)]
            [InstallationExport[]] $Exports
        )
        begin {
            $sortProperties = @(
                @{ Expression = { $_.Id.Provider }},
                @{ Expression = { $_.Id.Export }},
                'Name'
            )
        }
        process {
            $pins = Get-InstallationPins
            $Exports |
                ForEach-Object {
                    & $PSScriptRoot/get-export-script.ps1 -Id $_.Id.ToString() -Check
                } |
                ForEach-Object -Parallel {
                    & $_
                } |
                ForEach-Object {
                    $upgrade = $_
                    $matchingPin = $pins |
                        Where-Object { $_.Id -eq $upgrade.Id }
                    if ($null -ne $matchingPin) {
                        $upgradeVersion = [InstallationVersion]::new($upgrade.Available)
                        if ($null -eq $matchingPin.Version -or $matchingPin.Version -eq $upgradeVersion) {
                            return
                        }
                    }

                    $upgrade
                } |
                Sort-Object -Property $sortProperties
        }
    }

    enum ConfirmationChoice {
        Yes
        No
        Refresh
    }

    function Read-Choice {
        [CmdletBinding()]
        [OutputType([ConfirmationChoice])]
        param()
        begin {
            $confirmationChoicesDisplay = [ConfirmationChoice].GetEnumNames() -join '/'
        }
        process {
            $text = Read-Host -Prompt "Do you want to apply the upgrades [$confirmationChoicesDisplay]?"
            if (-not $text) {
                return $null
            }

            foreach ($choice in [ConfirmationChoice].GetEnumValues()) {
                $choiceText = $choice.ToString()
                if ($text -eq $choiceText) {
                    return $choice
                } elseif ($choiceText.StartsWith($text, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $choice
                }
            }
        }
    }
}
process {
    $exports = & $PSScriptRoot/get-exports.ps1 -Provider $Provider -Export $Export -Versioned
    $upgrades = Get-Upgrades -Exports $exports
    $disabledUpdates = Get-InstallationIds -FileName 'disabled-updates'

    if ($upgrades.Length -gt 0) {
        $displayProperties = @(
            @{ Name = 'Provider'; Expression = { $_.Id.Provider }},
            @{ Name = 'Export'; Expression = { $_.Id.Export }},
            'Name',
            'Current',
            'Available',
            @{ Name = 'Automated'; Expression = { $_.Id -notin $disabledUpdates }}
        )
        $upgrades |
            Select-Object -Property $displayProperties |
            Format-Table
    } else {
        Write-Output 'No upgrades found.'
    }

    & "$env:HOME/.local/bin/env/end-loading.ps1"

    $automatedUpgrades = $upgrades |
        Where-Object { $_.Id -notin $disabledUpdates }
    if ($automatedUpgrades.Length -eq 0 -or $Show) {
        exit 0
    }

    $script:selectedChoice = $null
    do {
        $script:selectedChoice = Read-Choice
    }
    while ($null -eq $script:selectedChoice)

    if ($script:selectedChoice -eq [ConfirmationChoice]::No) {
        exit 0
    }

    if ($script:selectedChoice -eq [ConfirmationChoice]::Refresh) {
        $upgrades = Get-Upgrades -Exports $exports
        $automatedUpgrades = $upgrades |
            Where-Object { $_.Id -notin $disabledUpdates }
    }

    try {
        & "$env:HOME/.local/bin/env/begin-loading.ps1"

        Write-Output ''
        $upgradeCounter = 1
        $upgradeTotal = $automatedUpgrades -is [array] ? $automatedUpgrades.Length : 1
        $automatedUpgrades |
            ForEach-Object {
                $exportId = "$($_.Id.Provider).$($_.Id.Export)"
                Write-Output "${exportId}: Updating $($_.Id.Value) ($upgradeCounter/$upgradeTotal)."

                $scriptPath = & $PSScriptRoot/get-export-script.ps1 -Id $exportId -Update

                if (-not $DryRun) {
                    & $scriptPath -Id $_.Id.Value
                }

                $upgradeCounter++
            }

        if (-not $DryRun) {
            $upgradedExports = $automatedUpgrades |
                ForEach-Object { "$($_.Id.Provider).$($_.Id.Export)" } |
                Select-Object -Unique
            & $PSScriptRoot/export-software.ps1 -Export $upgradedExports
        }
    }
    finally {
        & "$env:HOME/.local/bin/env/end-loading.ps1"
    }
}
