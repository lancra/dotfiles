#Requires -Modules powershell-yaml

[CmdletBinding()]
param (
    [Parameter()]
    [string] $Scope
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

$getMachineModuleDefinition = ${function:Get-MachineModule}.ToString()
$installedModules = @(
    @{ Executable = 'powershell'; Source = 'Windows' },
    @{ Executable = 'pwsh'; Source = 'Core' }
) |
    ForEach-Object -Parallel {
        ${function:Get-MachineModule} = $using:getMachineModuleDefinition
        @(Get-MachineModule @_)
    }

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

$modules |
    ForEach-Object {
        $matchingLocations = @($_.Locations |
            Where-Object { -not $Scope -or $_.Scope -eq $Scope } |
            Select-Object -ExpandProperty Name)

        if ($matchingLocations.Length -gt 0) {
            [ordered]@{
                Id = $_.Name
                Shell = $_.Shell
                Locations = $matchingLocations
            }
        }
    }
