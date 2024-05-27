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
    [string]$Provider
)
begin {
    & "$env:XDG_CONFIG_HOME/env/begin-loading.ps1"
}
process {
    & "$env:XDG_CONFIG_HOME/env/get-providers.ps1" -Id $Provider |
        ForEach-Object -Parallel {
            if ($_.check) {
                & "$env:XDG_CONFIG_HOME/$($_.id)/check-$($_.resource).ps1"
            }
        } |
        ConvertFrom-Json |
        Select-Object -Property provider,id,current,available |
        Sort-Object -Property provider,id |
        Format-Table
}
end {
    & "$env:XDG_CONFIG_HOME/env/end-loading.ps1"
}
