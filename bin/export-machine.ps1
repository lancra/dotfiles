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
    function Publish-Export {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Name,
            [Parameter(Mandatory)]
            [string]$Script,
            [Parameter(Mandatory)]
            [string]$Target
        )
        process {
            Write-Host "Exporting $Name..." -NoNewline
            & $Script -Target $Target
            Write-Host 'Done'
        }
    }

    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    & "$env:XDG_CONFIG_HOME/env/get-providers.ps1" -Id $Provider |
        ForEach-Object {
            if ($_.export) {
                $name = "$($_.id) $($_.resource)"
                $directory = "$env:XDG_CONFIG_HOME/$($_.id)"
                $script = "$directory/export-$($_.resource).ps1"
                $target = "$directory/$($_.resource).$($_.store)"
                Publish-Export -Name $name -Script $script -Target $target
            }
        }
}
end {
    Write-Host $endLoading -NoNewline
}
