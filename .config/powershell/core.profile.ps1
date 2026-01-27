# NOTE: This functionality must live in the profile script.
#       Moving to a centralized setup script results in the profile scripts being dot-sourced into the wrong scope.
[CmdletBinding(SupportsShouldProcess)]
param()

function Get-NormalizedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        return $Path -replace '\\', '/'
    }
}

$scriptsDirectoryPath = Get-NormalizedPath -Path "$env:BIN/powershell/profile"
$getScriptsArguments = @{
    Path = $scriptsDirectoryPath
    Filter = '*.ps1'
    Recurse = $true
}
$scriptPaths = [System.Collections.Generic.List[string]](Get-ChildItem @getScriptsArguments |
    Sort-Object -Property FullName |
    ForEach-Object {
        Get-NormalizedPath -Path $_.FullName
    })

$dependencies = Get-Content -Path "$env:XDG_CONFIG_HOME/powershell/profile.jsonc" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty 'dependencies'

$scriptNotFoundMessageFormat = 'The {0} profile script was not found. Consider removing it from the PowerShell profile configuration.'
$dependencies.PSObject.Properties |
    Sort-Object |
    ForEach-Object {
        $dependent = $_.Name
        $dependentPath = "$scriptsDirectoryPath/$dependent.ps1"
        $dependentIndex = $scriptPaths.IndexOf($dependentPath)
        if ($dependentIndex -eq -1) {
            Write-Warning ($scriptNotFoundMessageFormat -f $dependent)
            return
        }

        $dependencyIndexes = $_.Value |
            ForEach-Object {
                $dependency = $_
                $dependencyPath = "$scriptsDirectoryPath/$dependency.ps1"
                $dependencyIndex = $scriptPaths.IndexOf($dependencyPath)
                if ($dependencyIndex -eq -1) {
                    Write-Warning ($scriptNotFoundMessageFormat -f "$dependency dependency for the $dependent")
                    return
                }

                return $dependencyIndex
            }

        $maxDependencyIndex = $dependencyIndexes |
            Measure-Object -Maximum |
            Select-Object -ExpandProperty Maximum

        $scriptPaths.RemoveAt($dependentIndex)
        $scriptPaths.Insert($maxDependencyIndex, $dependentPath)
    }

$scriptPaths |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_, '.')) {
            . $_
        }
    }
