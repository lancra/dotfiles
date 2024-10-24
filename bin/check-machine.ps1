[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript({
        $_ -in (& "$env:XDG_CONFIG_HOME/env/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Provider') {
            $validProviders = (& "$env:XDG_CONFIG_HOME/env/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string]$Provider,
    [switch]$Interactive
)
begin {
    & "$env:XDG_CONFIG_HOME/env/begin-loading.ps1"
}
process {
    $outdatedItems = & "$env:XDG_CONFIG_HOME/env/get-providers.ps1" -Id $Provider |
        ForEach-Object -Parallel {
            if ($_.check) {
                & "$env:XDG_CONFIG_HOME/$($_.id)/check-$($_.resource).ps1"
            }
        } |
        ConvertFrom-Json |
        Select-Object -Property provider,id,current,available |
        Sort-Object -Property provider,id

    & "$env:XDG_CONFIG_HOME/env/end-loading.ps1"

    $hasOutdated = $outdatedItems.Count -gt 0
    if ($hasOutdated) {
        $outdatedItems | Format-Table
    } else {
        Write-Output 'No changes detected.'
    }

    if ($hasOutdated -and $Interactive) {
        $continueInput = 'y'
        $cancelInput = 'N'
        $validInputs = @($continueInput, $cancelInput)

        $script:input = ''
        do {
            $script:input = Read-Host -Prompt "Continue with update and export? ($continueInput/$cancelInput)"
        } while ($script:input -and -not ($validInputs -like $script:input))

        if (-not $script:input.Equals($continueInput, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Output 'Canceled update and export.'
            exit 0
        }

        Write-Output ''

        & update-machine.ps1 && & export-machine.ps1
    }
}
