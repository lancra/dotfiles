[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Configuration')]
    [switch] $Configuration,

    [Parameter(ParameterSetName = 'Data')]
    [switch] $Data
)

$machinePath = "machine/$($env:COMPUTERNAME.ToLower())"

$machineDirectoryPath = $null
if ($Configuration) {
    $machineDirectoryPath = "$env:XDG_CONFIG_HOME/$machinePath"
} elseif ($Data) {
    $machineDirectoryPath = "$env:XDG_DATA_HOME/$machinePath"
}

if ($null -eq $machineDirectoryPath) {
    throw 'Unable to resolve unrecognized machine directory.'
}

if (-not (Test-Path -Path $machineDirectoryPath)) {
    New-Item -ItemType Directory -Path $machineDirectoryPath -Force | Out-Null
}

$machineDirectoryPath
