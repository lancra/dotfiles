[CmdletBinding()]
[OutputType([System.Collections.IDictionary])]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [PSCustomObject] $Object,

    [switch] $Ordered
)

$hashtable = $Ordered ? [ordered]@{} : @{}

$Object.PSObject.Properties |
    ForEach-Object {
        $hashtable[$_.Name] = $_.Value
    }

return $hashtable
