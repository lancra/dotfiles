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

$script:timings = @()
$script:timer = [System.Diagnostics.Stopwatch]::new()

function Add-Timing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Section
    )
    process {
        $script:timings += ,[pscustomobject]@{
            Section = $Section
            ElapsedMilliseconds = $script:timer.ElapsedMilliseconds
        }

        $script:timer.Restart()
    }
}

function Export-Timings {
    [CmdletBinding()]
    param()
    begin {
        $timingsDirectory = "$env:XDG_STATE_HOME/powershell/profile"
        $timingsDate = Get-Date
        $timingsPath = "$timingsDirectory/timings.$($timingsDate.ToString('yyyyMMddTHHmmssfff')).json"
    }
    process {
        New-Item -Path $timingsDirectory -ItemType Directory -Force | Out-Null

        $entryProperties = @(
            @{ Name = 'name'; Expression = { $_.Section }},
            @{ Name = 'milliseconds'; Expression = { $_.ElapsedMilliseconds }}
        )
        $entries = $script:timings |
            Select-Object -Property $entryProperties

        $processPath = Get-Process -Id $PID |
            Select-Object -ExpandProperty Parent |
            Select-Object -ExpandProperty Path

        $totalMilliseconds = [int]($entries |
            Measure-Object -Property 'milliseconds' -Sum |
            Select-Object -ExpandProperty Sum)

        $timings = [pscustomobject]@{
            date = $timingsDate.ToString('yyyy-MM-ddTHH:mm:ss.fff')
            process = $processPath
            total = $totalMilliseconds
            entries = $entries
        } |
            ConvertTo-Json |
            Set-Content -Path $timingsPath
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

$script:timer.Start()
$scriptPaths |
    ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_, '.')) {
            . $_

            Add-Timing -Section $_.Substring($scriptsDirectoryPath.Length + 1)
        }
    }

Export-Timings
