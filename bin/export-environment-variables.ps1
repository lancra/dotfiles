#Requires -Modules powershell-yaml

[CmdletBinding()]
param (
    [Parameter()]
    [string]$Name = 'default'
)

function Get-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([ordered])]
    param (
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string[]]$IgnoredSubkeys
    )
    begin {
        $registryValueOptions = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    }
    process {
        $environmentVariables = [ordered]@{}
        $registryKey = Get-Item -Path $Key
        $registryKey |
            Select-Object -ExpandProperty Property |
            Sort-Object |
            ForEach-Object {
                $key = $_.ToUpper()
                if ($IgnoredSubkeys -contains $key) {
                    return
                }

                $value = $registryKey.GetValue($_, '', $registryValueOptions)
                if ($key -eq 'PATH') {
                    $value = $value -split ';' -ne ''
                }

                $environmentVariables[$key] = $value
            }

        $environmentVariables
    }
}

$variables = [ordered]@{}

$builtInUserVariables = @(
    'TEMP',
    'TMP'
)
$getUserVariablesArgs = @{
    Key = 'HKCU:\Environment'
    IgnoredSubkeys = $builtInUserVariables
}
$variables['User'] = Get-EnvironmentVariable @getUserVariablesArgs

$builtInMachineVariables = @(
    'COMSPEC',
    'CONFIGSETROOT',
    'DRIVERDATA',
    'NUMBER_OF_PROCESSORS',
    'OS',
    'PATHEXT',
    'POWERSHELL_DISTRIBUTION_CHANNEL',
    'PROCESSOR_ARCHITECTURE',
    'PROCESSOR_IDENTIFIER',
    'PROCESSOR_LEVEL',
    'PROCESSOR_REVISION',
    'PSMODULEPATH',
    'TEMP',
    'TMP',
    'USERNAME',
    'WINDIR'
)
$getMachineVariablesArgs = @{
    Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    IgnoredSubkeys = $builtInMachineVariables
}
$variables['Machine'] = Get-EnvironmentVariable @getMachineVariablesArgs

$envDirectory = "$env:XDG_CONFIG_HOME/lancra/env"
New-Item -ItemType Directory -Path $envDirectory -Force | Out-Null

$envPath = "$envDirectory/$Name.yaml"
$variables | ConvertTo-Yaml |
    Set-Content -Path $envPath
