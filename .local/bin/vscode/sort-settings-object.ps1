[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [pscustomobject] $Settings
)

$objectArraySortProperties = @{
    'editor.rulers' = 'column'
    'json.schemas' = 'url'
    'mssql.connectionGroups' = 'name'
    'mssql.connections' = 'profileName'
    'todohighlight.keywords' = 'text'
}

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
                    if ($_.Value -is [array]) {
                        $sortProperty = $_.Value.Length -gt 0 -and $_.Value[0] -is [pscustomobject] `
                            ? $objectArraySortProperties[$propertyName] `
                            : '$null'
                        $propertyValueAccessor = "@(`$_.Value | Sort-Object -Property '$sortProperty')"
                    } else {
                        $propertyValueAccessor = '$_.Value'
                    }

                    "$targetReference$Accessor | Add-Member -MemberType NoteProperty -Name '$propertyName' -Value $propertyValueAccessor" |
                        Invoke-Expression
                }
            }
    }
}

$sortedSettings = [pscustomobject]@{}
New-SortedSettings -Target $sortedSettings -Source $Settings

$sortedSettings |
    ConvertTo-Json -Depth 10
