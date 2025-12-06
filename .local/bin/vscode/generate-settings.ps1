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
$addPropertyFormat = '{0} | Add-Member -MemberType NoteProperty -Name ''{1}'' -Value {2}'
$expandEnvironmentVariablesFormat = '([System.Environment]::ExpandEnvironmentVariables({0}))'
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
                $propertyValueAccessor = '$_.Value'

                $targetObjectAccessor = "$targetReference$Accessor"
                $targetPropertyAccessor = "$targetReference$propertyAccessor"
                $targetPropertyValue = $targetPropertyAccessor |
                    Invoke-Expression

                if ($_.Value -is [array]) {
                    if ($null -eq $targetPropertyValue) {
                        $addPropertyFormat -f $targetObjectAccessor, $propertyName, '@()' |
                            Invoke-Expression
                    }

                    for ($i = 0; $i -lt $_.Value.Length; $i++) {
                        $propertyElementValue = $_.Value[$i]
                        $propertyElementValueAccessor = '$_.Value[$i]'

                        # This structure assumes that nested arrays are not part of VS Code settings.
                        if ($propertyElementValue -is [pscustomobject]) {
                            "$targetPropertyAccessor += ([pscustomobject]@{})" |
                                Invoke-Expression
                            Add-SettingsProperty -Target $Target -Source $propertyElementValue -Accessor "$propertyAccessor[$i]"
                        } elseif ($propertyElementValue -is [string]) {
                            "$targetPropertyAccessor += $($expandEnvironmentVariablesFormat -f '$_.Value[$i]')" |
                                Invoke-Expression
                        } else {
                            "$targetPropertyAccessor += $propertyElementValueAccessor" |
                                Invoke-Expression
                        }
                    }
                } elseif ($_.Value -is [pscustomobject]) {
                    if ($null -eq $targetPropertyValue) {
                        $addPropertyFormat -f $targetObjectAccessor, $propertyName, '([pscustomobject]@{})' |
                            Invoke-Expression
                    }

                    Add-SettingsProperty -Target $Target -Source $_.Value -Accessor $propertyAccessor
                } else {
                    if ($null -ne $targetPropertyValue) {
                        Write-Output "`e[31mDuplicate definitions found for `"$propertyAccessor`".`e[39m"
                        return
                    }

                    if ($_.Value -is [string]) {
                        $addPropertyFormat -f $targetObjectAccessor, $propertyName, ($expandEnvironmentVariablesFormat -f $propertyValueAccessor) |
                            Invoke-Expression
                    } else {
                        $addPropertyFormat -f $targetObjectAccessor, $propertyName, $propertyValueAccessor |
                            Invoke-Expression
                    }
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

& "$env:BIN/vscode/sort-settings-object.ps1" -Settings $aggregateSettings |
    Set-Content -Path $Path
