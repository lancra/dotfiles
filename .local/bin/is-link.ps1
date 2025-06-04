<#
.SYNOPSIS
Determines whether a filesystem item is a symbolic link.

.DESCRIPTION
Gets the item from the filesystem and determines whether the link type is set.

.PARAMETER Path
The path of the item to check.
#>
[CmdletBinding()]
[OutputType([bool])]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Path
)

$item = Get-Item -Path $Path
return $null -ne $item.LinkType
