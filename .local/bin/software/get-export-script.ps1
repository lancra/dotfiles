using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName = 'Check')]
    [Parameter(Mandatory, ParameterSetName = 'Export')]
    [string] $Id,

    [Parameter(ParameterSetName = 'Check')]
    [switch] $Check,

    [Parameter(ParameterSetName = 'Export')]
    [switch] $Export
)

$scriptPrefix = $null
if ($Check) {
    $scriptPrefix = 'check-'
} elseif ($Export) {
    $scriptPrefix = 'export-'
}

if ($null -eq $scriptPrefix) {
    throw 'Unable to resolve the unrecognized software script type.'
}

$targetExport = & $PSScriptRoot/get-exports.ps1 -Export $Id
if ($null -eq $targetExport) {
    throw "Unable to resolve the unrecognized $Id export."
}

if (-not $targetExport.Versioned -and $Check) {
    throw "Unable to resolve a check script for the non-versioned $Id export."
}

"$env:HOME/.local/bin/software/$($targetExport.Id.Provider)/$scriptPrefix$($targetExport.Name).ps1"
