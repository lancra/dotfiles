#Requires -Modules powershell-yaml

[CmdletBinding()]
param ()

$moduleLocations = @(
    @{ Name = 'User.Core'; VerbatimPath = '$env:USERPROFILE\Documents\PowerShell\Modules' },
    @{ Name = 'User.Windows'; VerbatimPath = '$env:USERPROFILE\Documents\WindowsPowerShell\Modules' },
    @{ Name = 'Application.Core'; VerbatimPath = '$env:PROGRAMFILES\PowerShell\7\Modules' },
    @{ Name = 'Application.Windows'; VerbatimPath = '$env:PROGRAMFILES\WindowsPowerShell\Modules' },
    @{ Name = 'System.Windows'; VerbatimPath = '$env:SYSTEMROOT\system32\WindowsPowerShell\v1.0\Modules' }
) |
ForEach-Object {
    $_.Path = $ExecutionContext.InvokeCommand.ExpandString($_.VerbatimPath)
    $_
}

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
        $location = [ordered]@{ name = 'Unknown' }
        foreach ($moduleLocation in $moduleLocations) {
            if ($Path.StartsWith($moduleLocation.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
                $location = [ordered]@{
                    name = $moduleLocation.Name
                    path = $Path.Replace(
                        $moduleLocation.Path,
                        $moduleLocation.VerbatimPath,
                        [System.StringComparison]::OrdinalIgnoreCase)
                }
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
            Sort-Object -Property @{ Expression = { $_['name'] } })

        [ordered]@{
            name = $_
            shell = $shell
            locations = $locations
        }
    }

$directoryPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'powershell'
New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null
$modulesPath = Join-Path -Path $directoryPath -ChildPath 'modules.yaml'

$output |
    ConvertTo-Yaml |
    Set-Content -Path $modulesPath
