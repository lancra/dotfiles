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

function Get-InstalledModule {
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

$modules = @()
$modules += @(Get-InstalledModule -Executable 'powershell' -Source 'Windows')
$modules += @(Get-InstalledModule -Executable 'pwsh' -Source 'Core')

$output = @{}
$output.modules = $modules |
    Select-Object -ExpandProperty Name -Unique |
    Sort-Object |
    ForEach-Object {
        $matchingModules = @($modules |
            Where-Object -Property Name -EQ $_)

        $shell = $matchingModules.Count -gt 1 ? 'Both' : $matchingModules[0].Source

        $locations = @($matchingModules |
            Select-Object -ExpandProperty Path -Unique |
            ForEach-Object { Get-ModuleLocation -Path $_ } |
            Sort-Object -Property @{ Expression = { $_['Order'] }}, @{ Expression = { $_['Name'] }} |
            ForEach-Object { $_['Name'] })

        [ordered]@{
            name = $_
            shell = $shell
            locations = $locations
        }
    }

$output |
    ConvertTo-Yaml |
    Set-Content -Path $Target
