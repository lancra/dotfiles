[CmdletBinding()]
param(
    [Parameter()]
    [string] $Provider,

    [Parameter()]
    [string] $Export,

    [Parameter()]
    [string] $Name,

    [switch] $Versioned
)

& $PSScriptRoot/get-providers.ps1 -Provider $Provider |
    Select-Object -ExpandProperty Exports |
    ForEach-Object {
        if (($Export -and $_.Id.ToString() -ne $Export) -or
            ($Name -and $_.Name -ne $Name) -or
            ($Versioned -and -not $_.Versioned)) {
                return
            }

        $_
    }
