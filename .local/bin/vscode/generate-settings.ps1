[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = "$env:XDG_CONFIG_HOME/vscode/settings.json"
)

$sourceDirectory = Join-Path $env:XDG_CONFIG_HOME -ChildPath 'vscode' -AdditionalChildPath 'settings'
$generators = @{
    'mssql.connections.json' = "$env:BIN/vscode/generate-mssql-connections-settings.ps1"
}

$schemaProperty = '$schema'
function Add-SettingsProperty {
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
        $Source.PSObject.Properties |
            Where-Object -Property Name -NE $schemaProperty |
            ForEach-Object {
                $propertyName = $_.Name
                $propertyAccessor = "$Accessor.'$propertyName'"
                $targetPropertyValue = "$targetReference$propertyAccessor" |
                    Invoke-Expression
                if ($null -eq $targetPropertyValue) {
                    $propertyValue = '$_.Value'
                    "$targetReference$Accessor | Add-Member -MemberType NoteProperty -Name '$propertyName' -Value $propertyValue" |
                        Invoke-Expression
                } elseif ($_.Value -is [pscustomobject]) {
                    Add-SettingsProperty -Target $Target -Source $_.Value -Accessor $propertyAccessor
                } else {
                    Write-Output "`e[31mDuplicate definitions found for `"$propertyAccessor`".`e[39m"
                }
            }
    }
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
                    $propertyValue = '$_.Value'
                    "$targetReference$Accessor | Add-Member -MemberType NoteProperty -Name '$propertyName' -Value $propertyValue" |
                        Invoke-Expression
                }
            }
    }
}

$aggregateSettings = [pscustomobject]@{}
Get-ChildItem -Path $sourceDirectory |
    ForEach-Object {
        if ($_.Name.EndsWith('.settings.json')) {
            $settings = Get-Content -Path $_.FullName |
                ConvertFrom-Json
        } else {
            $generator = $generators[$_.Name]
            $settings = & $generator -Source $_.FullName |
                ConvertFrom-Json
        }

        Add-SettingsProperty -Target $aggregateSettings -Source $settings
    }

$sortedSettings = [pscustomobject]@{}
New-SortedSettings -Target $sortedSettings -Source $aggregateSettings

$sortedSettings |
    ConvertTo-Json -Depth 3 |
    Set-Content -Path $Path
