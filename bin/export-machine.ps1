[CmdletBinding()]
param ()
begin {
    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    Write-Host 'Exporting winget packages...' -NoNewline
    & (Join-Path -Path $PSScriptRoot -ChildPath 'export-winget-packages.ps1')
    Write-Host 'Done'

    Write-Host 'Exporting environment variables...' -NoNewline
    & (Join-Path -Path $PSScriptRoot -ChildPath 'export-environment-variables.ps1')
    Write-Host 'Done'
}
end {
    Write-Host $endLoading -NoNewline
}
