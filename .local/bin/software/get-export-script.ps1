using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName = 'Check')]
    [Parameter(Mandatory, ParameterSetName = 'Export')]
    [string] $Id,

    [Parameter(ParameterSetName = 'Export')]
    [switch] $Export
)

$scriptPrefix = $null
if ($Export) {
    $scriptPrefix = 'export-'
}

if ($null -eq $scriptPrefix) {
    throw 'Unable to resolve unrecognized software script type.'
}

$targetExport = & $PSScriptRoot/get-exports.ps1 -Export $Id
if ($null -eq $targetExport) {
    throw "Unable to resolve unrecognized $Id export."
}

"$env:HOME/.local/bin/software/$($targetExport.Id.Provider)/$scriptPrefix$($targetExport.Name).ps1"
