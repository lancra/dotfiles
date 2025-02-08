[CmdletBinding()]
[OutputType([bool])]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Path
)

$item = Get-Item -Path $Path
return $null -ne $item.LinkType
