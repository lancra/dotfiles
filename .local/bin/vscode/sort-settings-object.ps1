[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [pscustomobject] $Settings
)
function New-SortedSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Target,

        [Parameter(Mandatory)]
        [pscustomobject] $Source,

        [Parameter()]
        [string] $Accessor
    )
    process {
        $targetReference = '$Target'
        $initialValue = '([PSCustomObject]@{})'
        $Source.PSObject.Properties |
            Sort-Object -Property Name |
            ForEach-Object {
                $propertyName = $_.Name

                if ($_.Value -is [pscustomobject]) {
                    "$targetReference$Accessor | Add-Member -MemberType NoteProperty -Name '$propertyName' -Value $initialValue" |
                        Invoke-Expression
                    New-SortedSettings -Target $Target -Source $_.Value -Accessor "$Accessor.'$propertyName'"
                } else {
                    $propertyValue = '$_.Value'
                    "$targetReference$Accessor | Add-Member -MemberType NoteProperty -Name '$propertyName' -Value $propertyValue" |
                        Invoke-Expression
                }
            }
    }
}

$sortedSettings = [pscustomobject]@{}
New-SortedSettings -Target $sortedSettings -Source $Settings

$sortedSettings |
    ConvertTo-Json -Depth 10
