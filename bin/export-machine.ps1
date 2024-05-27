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
    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    & "$env:XDG_CONFIG_HOME/env/get-providers.ps1" -Id $Provider |
        ForEach-Object -Parallel {
            if ($_.export) {
                $directory = "$env:XDG_CONFIG_HOME/$($_.id)"
                $script = "$directory/export-$($_.resource).ps1"
                $target = "$directory/$($_.resource).$($_.store)"
                & $script -Target $target
            }
        }
}
end {
    Write-Host $endLoading -NoNewline
}
