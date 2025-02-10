#Requires -Modules powershell-yaml

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

class ModuleLocation {
    [string] $Name
    [string] $Path
    [string] $Scope
    [int] $Order

    ModuleLocation([string] $name, [string] $path, [string] $scope, [int] $order) {
        $this.Name = $name
        $this.Path = $path
        $this.Scope = $scope
        $this.Order = $order
    }
}

class Module {
    [string] $Name
    [string] $Shell
    [ModuleLocation[]] $Locations

    Module([string] $name, [string] $shell, [ModuleLocation[]] $locations) {
        $this.Name = $name
        $this.Shell = $shell
        $this.Locations = $locations
    }
}

$unknownModuleLocation = [ordered]@{ Name = 'Unknown'; Path = 'C:\'; Order = 0 }
$moduleLocations = @(
    [ModuleLocation]::new('User.Core', "$env:USERPROFILE\Documents\PowerShell\Modules", 'User', 1),
    [ModuleLocation]::new('User.Windows', "$env:USERPROFILE\Documents\WindowsPowerShell\Modules", 'User', 1),
    [ModuleLocation]::new('Application.Core', "$env:PROGRAMFILES\PowerShell\7\Modules", 'Machine', 2),
    [ModuleLocation]::new('Application.Windows', "$env:PROGRAMFILES\WindowsPowerShell\Modules", 'Machine', 2),
    [ModuleLocation]::new('System.Windows', "$env:SYSTEMROOT\system32\WindowsPowerShell\v1.0\Modules", 'Machine', 3)
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
        $shellCommand = "& $Executable -NoProfile -Command '$getModulesJsonCommand'"
    }
    process {
        Invoke-Command -ScriptBlock ([scriptblock]::Create($shellCommand)) |
            ConvertFrom-Json |
            Select-Object -Property *, @{ Name = 'Source'; Expression = { $Source }}
    }
}

function Get-ModuleLocation {
    [CmdletBinding()]
    [OutputType([ModuleLocation])]
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
            Sort-Object -Property Order, Name)

        [Module]::new($name, $shell, $locations)
    }

function Export-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [Module[]] $Modules,

        [Parameter(Mandatory)]
        [string] $Scope
    )
    process {
        $Modules |
            ForEach-Object {
                $matchingLocations = @($_.Locations |
                    Where-Object -Property Scope -EQ $Scope |
                    Select-Object -ExpandProperty Name)

                if ($matchingLocations.Length -gt 0) {
                    [ordered]@{
                        name = $_.Name
                        shell = $_.Shell
                        locations = $matchingLocations
                    }
                }
            } |
            ConvertTo-Yaml |
            Set-Content -Path $Path
    }
}

Export-Module -Path $Target -Modules $modules -Scope 'User'

$machineDirectoryPath = "$env:HOME/.local/share/machine/$($env:COMPUTERNAME.ToLower())/powershell"
New-Item -ItemType Directory -Path $machineDirectoryPath -Force | Out-Null

$machineTargetPath = "$machineDirectoryPath/modules.yaml"
Export-Module -Path $machineTargetPath -Modules $modules -Scope 'Machine'
