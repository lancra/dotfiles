#Requires -Modules powershell-yaml

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

$unknownModuleLocation = [ordered]@{ Name = 'Unknown'; Path = 'C:\'; Order = 0 }
$moduleLocations = @(
    [ordered]@{ Name = 'User.Core'; Path = "$env:USERPROFILE\Documents\PowerShell\Modules"; Order = 1 },
    [ordered]@{ Name = 'User.Windows'; Path = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"; Order = 1 },
    [ordered]@{ Name = 'Application.Core'; Path = "$env:PROGRAMFILES\PowerShell\7\Modules"; Order = 2 },
    [ordered]@{ Name = 'Application.Windows'; Path = "$env:PROGRAMFILES\WindowsPowerShell\Modules"; Order = 2 },
    [ordered]@{ Name = 'System.Windows'; Path = "$env:SYSTEMROOT\system32\WindowsPowerShell\v1.0\Modules"; Order = 3 }
)

function Get-MachineModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Executable,
        [Parameter(Mandatory)]
        [string]$Source
    )
    begin {
        $getModulesJsonCommand = 'Get-Module -ListAvailable | Select-Object -Property Name,Path | ConvertTo-Json'
        $shellCommand = "& $Executable -Command '$getModulesJsonCommand'"
    }
    process {
        Invoke-Command -ScriptBlock ([scriptblock]::Create($shellCommand)) |
            ConvertFrom-Json |
            Select-Object -Property *, @{ Name = 'Source'; Expression = { $Source }}
    }
}

function Get-ModuleLocation {
    [CmdletBinding()]
    [OutputType([ordered])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    process {
        $location = $unknownModuleLocation
        foreach ($moduleLocation in $moduleLocations) {
            if ($Path.StartsWith($moduleLocation.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
                $location = $moduleLocation
                break
            }
        }

        $location
    }
}

$installedModules = @()
$installedModules += @(Get-MachineModule -Executable 'powershell' -Source 'Windows')
$installedModules += @(Get-MachineModule -Executable 'pwsh' -Source 'Core')

$modules = $installedModules |
    Select-Object -ExpandProperty Name -Unique |
    Sort-Object |
    ForEach-Object {
        $name = $_

        $matchingModules = @()
        $coreModule = $installedModules |
            Where-Object { $_.Name -eq $name -and $_.Source -eq 'Core' } |
            Select-Object -First 1
        if ($null -ne $coreModule) {
            $matchingModules += $coreModule
        }

        $windowsModule = $installedModules |
            Where-Object { $_.Name -eq $name -and $_.Source -eq 'Windows' } |
            Select-Object -First 1
        if ($null -ne $windowsModule) {
            $matchingModules += $windowsModule
        }

        $shell = $matchingModules.Count -gt 1 ? 'Both' : $matchingModules[0].Source

        $locations = @($matchingModules |
            Select-Object -ExpandProperty Path -Unique |
            ForEach-Object { Get-ModuleLocation -Path $_ } |
            Sort-Object -Property @{ Expression = { $_['Order'] }}, @{ Expression = { $_['Name'] }} |
            ForEach-Object { $_['Name'] })

        [ordered]@{
            name = "$name"
            shell = "$shell"
            locations = $locations
        }
    }

$modules |
    ConvertTo-Yaml |
    Set-Content -Path $Target
