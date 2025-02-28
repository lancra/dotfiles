using module ./software.psm1

[CmdletBinding(DefaultParameterSetName = 'Provider')]
param (
    [Parameter(ParameterSetName = 'Provider', Position = 0)]
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
    [string] $Export,

    [switch] $Show,

    [switch] $DryRun
)
begin {
    & "$env:HOME/.local/bin/env/begin-loading.ps1"

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
            $Exports |
                ForEach-Object {
                    & $PSScriptRoot/get-export-script.ps1 -Id $_.Id.ToString() -Check
                } |
                ForEach-Object -Parallel {
                    & $_
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

    $hasUpgrades = $upgrades.Length -gt 0
    if ($hasUpgrades) {
        $displayProperties = @(
            @{ Name = 'Provider'; Expression = { $_.Id.Provider }},
            @{ Name = 'Export'; Expression = { $_.Id.Export }},
            'Name',
            'Current',
            'Available'
        )
        $upgrades |
            Select-Object -Property $displayProperties |
            Format-Table
    } else {
        Write-Output 'No upgrades found.'
    }

    & "$env:HOME/.local/bin/env/end-loading.ps1"

    if (-not $hasUpgrades -or $Show) {
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
    }

    try {
        & "$env:HOME/.local/bin/env/begin-loading.ps1"

        Write-Output ''
        $upgradeCounter = 1
        $upgradeTotal = $upgrades -is [array] ? $upgrades.Length : 1
        $upgrades |
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
            $exportParameters = @{}
            if ($Provider) {
                $exportParameters['Provider'] = $Provider
            }

            if ($Export) {
                $exportParameters['Export'] = $Export
            }

            & $PSScriptRoot/export-software.ps1 @exportParameters
        }
    }
    finally {
        & "$env:HOME/.local/bin/env/end-loading.ps1"
    }
}
