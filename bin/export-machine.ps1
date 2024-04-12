[CmdletBinding()]
param ()
begin {
    function Publish-Export {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Name,
            [Parameter(Mandatory)]
            [string]$Script
        )
        process {
            Write-Host "Exporting $Name..." -NoNewline
            & (Join-Path -Path $PSScriptRoot -ChildPath $Script)
            Write-Host 'Done'
        }
    }

    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    Publish-Export -Name 'winget packages' -Script 'export-winget-packages.ps1'
    Publish-Export -Name 'powershell modules' -Script 'export-powershell-modules.ps1'
    Publish-Export -Name 'pip packages' -Script 'export-pip-packages.ps1'
    Publish-Export -Name 'go packages' -Script 'export-go-packages.ps1'
    Publish-Export -Name 'environment variables' -Script 'export-environment-variables.ps1'
}
end {
    Write-Host $endLoading -NoNewline
}
