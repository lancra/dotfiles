<#
.SYNOPSIS
Resolves a relative path to a target path from a provided source path.

.DESCRIPTION
Determines whether the provided paths share a common ancestor. If so, the source
path (for a filesystem item which must exist) has parent directory segments
added to resolve to the common ancestor directory, and the remaining segments
from the target path are appended. This script handles target paths for
non-existent filesystem items.

.PARAMETER Source
The path of the source filesystem item to resolve from.

.PARAMETER Target
The path of the target filesystem item to resolve to.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string] $Source,

    [Parameter(Mandatory)]
    [string] $Target
)

$sourceItem = Get-Item -Path $Source -ErrorAction SilentlyContinue
if ($null -eq $sourceItem) {
    throw "Unable to find file or directory at $Source."
}

$absoluteSource = & resolve-relative-path.ps1 -Path $Source
$absoluteTarget = & resolve-relative-path.ps1 -Path $Target

$isSourceDirectory = $sourceItem.PSIsContainer
$sourceDirectory = $isSourceDirectory ? $absoluteSource : [System.IO.Path]::GetDirectoryName($absoluteSource)

$sourceUri = $null
$validSourceUri = [System.Uri]::TryCreate($sourceDirectory, [System.UriKind]::Absolute, [ref] $sourceUri)
if (-not $validSourceUri) {
    throw "Unable to parse a URI from '$Source'."
}

$targetUri = $null
$validTargetUri = [System.Uri]::TryCreate($absoluteTarget, [System.UriKind]::Absolute, [ref] $targetUri)
if (-not $validTargetUri) {
    throw "Unable to parse a URI from '$Target'."
}

$sourceSegments = $sourceUri.Segments[1..($sourceUri.Segments.Length - 1)]
$targetSegments = $targetUri.Segments[1..($targetUri.Segments.Length - 1)]

$minimumSegmentLength = [System.Math]::Min($sourceSegments.Length, $targetSegments.Length)
$sharedAncestorSegmentCount = 0
for ($i = 0; $i -lt $minimumSegmentLength; $i++) {
    if ($sourceSegments[$i].TrimEnd('/') -ne $targetSegments[$i].TrimEnd('/')) {
        break
    }

    $sharedAncestorSegmentCount++
}

if ($sharedAncestorSegmentCount -eq 0) {
    throw "Unable to determine relative path due to no common ancestors between the provided paths."
}

$relativeDistanceUp = $sourceSegments.Length - $sharedAncestorSegmentCount
$relativePathPrefixSegments = @()
for ($i = 0; $i -lt $relativeDistanceUp; $i++) {
    $relativePathPrefixSegments += '..'
}

$relativePathPrefix = $relativePathPrefixSegments.Length -gt 0 ? $relativePathPrefixSegments -join '/' : '.'

$relativePathSuffixSegments = $targetSegments[$sharedAncestorSegmentCount..($targetSegments.Length)]
$relativePathSuffix = $relativePathSuffixSegments -join ''

"$relativePathPrefix/$relativePathSuffix"
