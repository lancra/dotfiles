[CmdletBinding()]
[OutputType([System.Collections.IDictionary])]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [PSCustomObject] $Object,

    [switch] $Ordered,

    # NOTE: This parameter cannot be a string since PowerShell coerces null into an empty string. The intent is to support empty string
    #       as a possible separator, so usage of object is required to avoid coercion.
    [Parameter()]
    [object] $FlattenSeparator
)

$hashtable = $Ordered ? [ordered]@{} : @{}

class OutputProperty {
    [string[]] $Segments
    [string] $Accessor

    OutputProperty([string[]] $segments, [string] $accessor) {
        $this.Segments = $segments
        $this.Accessor = $accessor
    }

    [OutputProperty] CreateObjectChild([string] $name) {
        return [OutputProperty]::new(@($this.Segments) + $name, "$($this.Accessor).$name")
    }

    [OutputProperty] CreateArrayChild([int] $index) {
        return [OutputProperty]::new(@($this.Segments) + "$index", "$($this.Accessor)[$index]")
    }
}
$propertyQueue = [System.Collections.Generic.Queue[OutputProperty]]::new()

function Add-QueuedProperty {
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Object')]
        [PSCustomObject] $Object,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Array')]
        [array] $Array,

        [Parameter(Mandatory)]
        [OutputProperty] $ParentProperty,

        [switch] $Flatten
    )
    process {
        if ($Object) {
            $values = $Object.PSObject.Properties |
                Where-Object -Property MemberType -EQ NoteProperty |
                Select-Object @(
                    @{ Name = 'Property'; Expression = { $ParentProperty.CreateObjectChild($_.Name) }},
                    @{ Name = 'Value'; Expression = { $_.Value }}
                )
        } else {
            $values = @()
            for ($i = 0; $i -lt $Array.Length; $i++) {
                $values += [PSCustomObject]@{
                    Property = $ParentProperty.CreateArrayChild($i)
                    Value = $Array[$i]
                }
            }
        }

        $values |
            ForEach-Object {
                $isObject = $_.Value.GetType().Name -eq 'PSCustomObject'
                $isArray = $_.Value -is [array]

                if (-not $Flatten -or (-not $isObject -and -not $isArray)) {
                    $propertyQueue.Enqueue($_.Property)
                } else {
                    $addQueuedPropertyArguments = @{
                        ParentProperty = $_.Property
                        Flatten = $true
                    }

                    if ($isObject) {
                        $addQueuedPropertyArguments.Add('Object', $_.Value)
                    } elseif ($isArray) {
                        $addQueuedPropertyArguments.Add('Array', $_.Value)
                    }

                    Add-QueuedProperty @addQueuedPropertyArguments
                }
            }
    }
}

$rootProperty = [OutputProperty]::new(@(), '$Object')
$flatten = $null -ne $FlattenSeparator
Add-QueuedProperty -Object $Object -ParentProperty $rootProperty -Flatten:$flatten

while ($propertyQueue.Count -ne 0) {
    $property = $propertyQueue.Dequeue()

    $name = $property.Segments -join $FlattenSeparator
    $value = Invoke-Expression -Command $property.Accessor

    $hashtable.Add($name, $value)
}

return $hashtable
