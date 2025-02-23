using module ./software.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id,

    [Parameter(ParameterSetName = 'Check')]
    [switch] $Check,

    [Parameter(ParameterSetName = 'Export')]
    [switch] $Export,

    [Parameter(ParameterSetName = 'Update')]
    [switch] $Update
)

$targetExport = & $PSScriptRoot/get-exports.ps1 -Export $Id
if ($null -eq $targetExport) {
    throw "Unable to resolve the unrecognized $Id export."
}

if (-not $targetExport.Versioned -and ($Check -or $Update)) {
    throw "Unable to resolve a version administration script for the non-versioned $Id export."
}

$scriptPrefix = $null
$upsertPrefix = 'upsert-'
$singular = $false
if ($Check) {
    $scriptPrefix = 'check-'
} elseif ($Export) {
    $scriptPrefix = 'export-'
} elseif ($Update) {
    $scriptPrefix = $targetExport.Upsert ? $upsertPrefix : 'update-'
    $singular = $true
}

if ($null -eq $scriptPrefix) {
    throw 'Unable to resolve the unrecognized software script type.'
}

$scriptFileName = "$scriptPrefix$($targetExport.Name)"
if ($singular) {
    $scriptFileName = $scriptFileName.TrimEnd('s')
}

"$env:HOME/.local/bin/software/$($targetExport.Id.Provider)/$scriptFileName.ps1"
