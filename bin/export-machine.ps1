[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript({
        $_ -in (Get-Content -Path "$env:XDG_CONFIG_HOME/env/providers.json" | jq -r '.providers.[] | .id')},
        ErrorMessage = 'Provider not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Provider') {
            $validProviders = @(Get-Content -Path "$env:XDG_CONFIG_HOME/env/providers.json" | jq -r '.providers.[] | .id')
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

    $providersPath = "$env:XDG_CONFIG_HOME/env/providers.json"

    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    $providers = Get-Content -Path $providersPath |
        ConvertFrom-Json |
        Select-Object -ExpandProperty providers

    $targetProviders = $providers
    if ($Provider) {
        $targetProviders = $providers |
            Where-Object -Property id -EQ $Provider
    }

    $targetProviders |
        ForEach-Object {
            $name = "$($_.id) $($_.resource)"
            $directory = "$env:XDG_CONFIG_HOME/$($_.id)"
            $script = "$directory/$($_.export)"
            $target = "$directory/$($_.resource).$($_.store)"
            Publish-Export -Name $name -Script $script -Target $target
        }
}
end {
    Write-Host $endLoading -NoNewline
}
