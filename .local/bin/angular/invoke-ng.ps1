#Requires -PSEdition Core

<#
.SYNOPSIS
Invokes an Angular command for a project nested within a specified path.

.DESCRIPTION
Finds all Angular projects within a specified path via a recursive search for
the angular.json configuration file. The target terminal is then determined by
the provided value or by the currently executing terminal if not provided.
Finally, the command is executed in the target terminal, either in the current
instance, a new tab or a new window, based on the provided parameters and the
terminal's capabilities.

.PARAMETER Action
The action to invoke, which is mapped to an underlying Angular CLI command.

.PARAMETER Path
The path to search for Angular projects from. The working directory is used by
default.

.PARAMETER Terminal
The terminal to run the command in. The currently executing terminal is used by
default, and PowerShell Core is used as a fallback when that cannot be
determined.

.PARAMETER Directory
The Angular project directory to filter search results by. No filtering is
applied to the search by default.

.PARAMETER Overwrite
When provided, the current terminal instance is overwritten by the target
command.

.PARAMETER Window
When provided, the command is executed in a new terminal window instead of a new
tab. For terminals that do not support tabs, this parameter is ignored.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('cd', 'open', 'o', 'serve', 's')]
    [string] $Action,

    [Parameter()]
    [string] $Path = $PWD,

    [Parameter()]
    [ValidateSet('pwsh', 'wt')]
    [string] $Terminal,

    [Parameter()]
    [string] $Directory,

    [switch] $Overwrite,
    [switch] $Window
)

function Test-Command {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )
    process {
        $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
    }
}

function Get-SearchDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    begin {
        $hasGit = Test-Command -Name 'git'
    }
    process {
        $searchDirectory = $Path
        if ($hasGit) {
            $repositoryRoot = & git -C $Path rev-parse --show-toplevel 2> $null
            if ($LASTEXITCODE -eq 0) {
                $searchDirectory = $repositoryRoot
            }
        }

        return $searchDirectory
    }
}

function Get-ProjectDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $SearchPath
    )
    begin {
        $hasFd = Test-Command -Name 'fd'
        $angularConfigurationFileName = 'angular.json'
    }
    process {
        $angularConfigurationPaths = @()

        # Prefer fd for performance, but fall back on native PowerShell for compatibility.
        if ($hasFd) {
            # fd requires two backslashes for path matching on Windows.
            $fdDirectorySeparator = [System.IO.Path]::DirectorySeparatorChar
            if ($fdDirectorySeparator -eq '\') {
                $fdDirectorySeparator += $fdDirectorySeparator
            }

            $fdSearchPathDirectorySegment = $Directory ? "$fdDirectorySeparator$Directory$fdDirectorySeparator.*" : $fdDirectorySeparator
            $fdSearchPath = "$fdSearchPathDirectorySegment$angularConfigurationFileName"
            $angularConfigurationPaths = @(& fd --full-path $fdSearchPath $SearchPath |
                # Sorting the results is required for deterministic execution since the search is multi-threaded.
                Sort-Object)
        } else {
            $ignoredDirectories = @('node_modules', '.angular')
            $angularConfigurationPaths = @(Get-ChildItem -Path $SearchPath -Recurse -Directory |
                Where-Object {
                    $include = $true
                    foreach ($directory in $ignoredDirectories) {
                        if ($_.FullName -ilike "*$directory*") {
                            $include = $false
                            break
                        }
                    }

                    return $include
                } |
                Get-ChildItem -Filter $angularConfigurationFileName |
                Select-Object -ExpandProperty FullName)
        }

        if ($angularConfigurationPaths.Length -gt 1) {
            $message = "`e[33mFound multiple Angular configuration files. Use the Directory parameter to isolate a single target."
            $angularConfigurationPaths |
                ForEach-Object {
                    $message += "$([System.Environment]::NewLine)  - $_"
                }

            $message += "`e[39m"
            Write-Host $message
        }

        return [System.IO.Path]::GetDirectoryName($angularConfigurationPaths[0])
    }
}

function Invoke-PowerShellCommand {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Command,

        [Parameter(Mandatory)]
        [string] $WorkingDirectory
    )
    process {
        # Ignore Window parameter since the PowerShell Core terminal does not support tabs.
        $arguments = @(
            '-NoProfile',
            ($Command ? "-Command $Command" : '-NoExit')
        )
        Start-Process -FilePath 'pwsh' -ArgumentList $arguments -WorkingDirectory $WorkingDirectory
    }
}

function Invoke-WindowsTerminalCommand {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Command,

        [Parameter(Mandatory)]
        [string] $WorkingDirectory
    )
    process {
        $windowIndex = $Window ? -1 : 0
        $wtCommandLine = $Command ? " pwsh -NoProfile -Command $Command" : ''
        $wtCommand = [scriptblock]::Create("wt --window $windowIndex new-tab --startingDirectory '$WorkingDirectory'$wtCommandLine")
        Invoke-Command -ScriptBlock $wtCommand
    }
}

function Get-TargetTerminal {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    begin {
        class ProcessTreeElement {
            [int] $Index
            [string] $Name
            [string] $Path

            ProcessTreeElement([int] $index, [string] $name, [string] $path) {
                $this.Index = $index
                $this.Name = $name
                $this.Path = $path
            }
        }

        function Get-ProcessTree {
            [CmdletBinding()]
            [OutputType([ProcessTreeElement[]])]
            param()
            begin {
                $index = 0
                $processes = @()
            }
            process {
                $process = Get-Process -Id $PID

                while ($null -ne $process) {
                    $processes += [ProcessTreeElement]::new($index, $process.Name, $process.Path)
                    $process = $process.Parent
                    $index++
                }

                return $processes
            }
        }

        $processTerminalMappings = @{
            'WindowsTerminal' = 'wt'
        }
    }
    process {
        $targetTerminal = $Terminal
        if ([string]::IsNullOrEmpty($targetTerminal)) {
            $targetTerminal = (Get-ProcessTree |
                ForEach-Object {
                    $processTerminal = $processTerminalMappings[$_.Name]
                    if ($null -ne $processTerminal) {
                        return $processTerminal
                    }
                }) ?? 'pwsh'
        }

        return $targetTerminal
    }
}

function Invoke-AngularCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ProjectPath,

        [Parameter(Mandatory)]
        [string] $TargetTerminal
    )
    begin {
        $actionCommandMappings = @{
            'open' = $null
            'serve' = 'ng serve'
        }
        $actionCommandMappings['cd'] = $actionCommandMappings['open']
        $actionCommandMappings['o'] = $actionCommandMappings['open']
        $actionCommandMappings['s'] = $actionCommandMappings['serve']
    }
    process {
        $command = $actionCommandMappings[$Action]
        if ($Overwrite) {
            Set-Location -Path $ProjectPath
            if ($command) {
                $commandScript = [scriptblock]::Create($command)
                Invoke-Command -ScriptBlock $commandScript
            }

            return
        }

        switch ($TargetTerminal) {
            'pwsh' { Invoke-PowerShellCommand -Command $command -WorkingDirectory $ProjectPath }
            'wt' { Invoke-WindowsTerminalCommand -Command $command -WorkingDirectory $ProjectPath }
        }
    }
}

$searchDirectory = Get-SearchDirectory
$projectDirectory = Get-ProjectDirectory -SearchPath $searchDirectory
if (-not $projectDirectory) {
    Write-Host "`e[31mNo Angular project was found within '$Path'.`e[39m"
    exit 1
}

$targetTerminal = Get-TargetTerminal
Invoke-AngularCommand -ProjectPath $projectDirectory -TargetTerminal $targetTerminal
