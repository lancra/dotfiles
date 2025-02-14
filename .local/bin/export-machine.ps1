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
            $script = "$env:HOME/.local/bin/$($_.id)/export-$($_.resource).ps1"
            $target = "$env:XDG_DATA_HOME/$($_.id)/$($_.resource).$($_.store)"
            & $script -Target $target
        }

    & "$env:HOME/.local/bin/env/export-variables.ps1"
}
end {
    & "$env:HOME/.local/bin/env/end-loading.ps1"
}
