[CmdletBinding()]
param(
    [Parameter()]
    [string] $Provider
)

& $PSScriptRoot/get-providers.ps1 -Provider $Provider |
    Select-Object -ExpandProperty Exports |
    ForEach-Object {
        $_.Id.ToString()
    }
