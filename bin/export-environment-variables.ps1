#Requires -Modules powershell-yaml

[CmdletBinding()]
param (
    [Parameter()]
    [string]$Target = "$env:XDG_CONFIG_HOME/env/variables.yaml"
)

$prefixVariableNames = @(
    'LOCALAPPDATA',
    'APPDATA',
    'USERPROFILE',
    'DEVUSERPROFILE',
    'HOME',
    'DEV_HOME',
    'SYSTEMROOT',
    'PROGRAMFILES(X86)',
    'PROGRAMFILES'
)

$prefixVariables = [ordered]@{}
$prefixVariableNames |
    ForEach-Object {
        $prefixVariables[$_] = [System.Environment]::GetEnvironmentVariable($_)
    }

function Set-PathPrefix {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Prefixes,
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$AllowExact
    )
    begin {
        $pathRegex = '[a-zA-Z]:[\\\/]'
    }
    process {
        if ($Path -notmatch $pathRegex) {
            Write-Verbose "$Path does not match the format for path prefixing."
            return $Path
        }

        foreach ($prefix in $Prefixes.GetEnumerator()) {
            $prefixPath = $prefix.Value
            Write-Verbose "  Testing Path=$Path, Prefx=$prefixPath"

            if ($Path -like "$prefixPath*" -and ($Path -ne $prefixPath -or $AllowExact)) {
                $prefixName = $prefix.Key
                $pathSuffix = $Path.Substring($prefixPath.Length)
                $resultPath = "%$prefixName%$pathSuffix"

                Write-Verbose "    Match=$resultPath"
                return $resultPath
            }
        }

        $Path
    }
}

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
                    Write-Verbose 'Processing PATH variable parts...'
                    $valueParts = $value -split ';' -ne ''
                    $prefixedParts = @()

                    foreach ($part in $valueParts) {
                        Write-Verbose "Processing $part from PATH..."
                        $prefixedParts += Set-PathPrefix -Prefixes $prefixVariables -Path $part -AllowExact
                    }

                    $value = $prefixedParts
                } else {
                    Write-Verbose "Processing $key variable..."
                    $value = Set-PathPrefix -Prefixes $prefixVariables -Path $value
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

$directory = [System.IO.Path]::GetDirectoryName($Target)
New-Item -ItemType Directory -Path $directory -Force | Out-Null

$variables | ConvertTo-Yaml |
    Set-Content -Path $Target
