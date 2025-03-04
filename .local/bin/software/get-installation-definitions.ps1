[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [InstallationExportId] $Export,

    [Parameter()]
    [string] $Id
)

$exportDefinition = & $PSScriptRoot/get-exports.ps1 -Provider $Export.Provider -Export $Export.ToString()
if ($null -eq $exportDefinition) {
    throw "The $Export export is undefined."
}

$path = "$env:XDG_DATA_HOME/software/$($exportDefinition.Id).yaml"
if (-not (Test-Path -Path $path)) {
    return @()
}

$definitions = (Get-Content -Path $path |
    ConvertFrom-Yaml -Ordered).GetEnumerator() |
    ForEach-Object { [PSCustomObject]$_ }

if ($Id) {
    $definitions = $definitions |
        Where-Object -Property Id -EQ $Id
}

return $definitions
