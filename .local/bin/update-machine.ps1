[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript({
        $_ -in (& "$env:HOME/.local/bin/env/get-provider-ids.ps1")},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Provider') {
            $validProviders = (& "$env:HOME/.local/bin/env/get-provider-ids.ps1")
            $validProviders -like "$wordToComplete*"
        }
    })]
    [string]$Provider
)
begin {
    & "$env:HOME/.local/bin/env/begin-loading.ps1"
}
process {
    & "$env:HOME/.local/bin/env/get-providers.ps1" -Id $Provider |
        ForEach-Object -Parallel {
            if ($_.check) {
                & "$env:HOME/.local/bin/$($_.id)/check-$($_.resource).ps1"
            }
        } |
        ConvertFrom-Json |
        Sort-Object -Property provider,id |
        ForEach-Object {
            Write-Host "$($_.provider): Updating $($_.id)..."
            $updateId = $_.id
            if ($_.provider -eq 'go') {
                $updateId = $_.path
            }

            & "$env:HOME/.local/bin/$($_.provider)/update.ps1" -Id $updateId
        }
}
end {
    & "$env:HOME/.local/bin/env/end-loading.ps1"
}
