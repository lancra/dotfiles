[CmdletBinding()]
param ()
begin {
    function Publish-Export {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Name,
            [Parameter(Mandatory)]
            [string]$Path
        )
        process {
            Write-Host "Exporting $Name..." -NoNewline
            & $Path
            Write-Host 'Done'
        }
    }

    $exportsPath = "$env:XDG_CONFIG_HOME/lancra/env/exports.json"

    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    $exports = Get-Content -Path $exportsPath |
        ConvertFrom-Json

    $exports |
        ForEach-Object {
            Publish-Export -Name $_.name -Path $_.path
        }
}
end {
    Write-Host $endLoading -NoNewline
}
