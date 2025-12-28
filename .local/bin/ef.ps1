<#
.SYNOPSIS
Manage Entity Framework Core migrations.

.DESCRIPTION
Provides a streamlined interface for the dotnet-ef global tool. Most executions
can be initiated by providing a single action, with others requiring an
additional name.

.PARAMETER Action
The action to execute.

.PARAMETER Name
The name of the migration.

.PARAMETER Path
The repository path.

.PARAMETER Project
The project containing the database migrations.

.PARAMETER StartupProject
The project used for migrations at run-time.

.PARAMETER BuildConfiguration
The configuration to use when executing a build.

.PARAMETER ConnectionVariable
The environment variable containing the database connection string.

.PARAMETER BundleDirectory
The artifacts relative path to the directory containing the bundle.

.PARAMETER IncludeBuild
Executes an application build prior to running the command.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Action,

    [Parameter(Position = 1)]
    [string] $Name,

    [Parameter()]
    [string] $Path = $PWD,

    [Parameter()]
    [string] $Project = 'src/Migrations',

    [Parameter()]
    [string] $StartupProject = 'tools/Migrator',

    [Parameter()]
    [string] $BuildConfiguration = 'Release',

    [Parameter()]
    [string] $ConnectionVariable = 'DATABASE_CONNECTION',

    [Parameter()]
    [string] $BundleDirectory = 'artifacts/db',

    [switch] $IncludeBuild
)

enum ScriptMessageLevel {
    Standard
    Warning
    Critical
}

class ScriptMessage {
    [string] $Content
    [ScriptMessageLevel] $Level

    ScriptMessage([string] $content, [ScriptMessageLevel] $level) {
        $this.Content = $content
        $this.Level = $level
    }
}

function Show-ScriptMessage {
    [CmdletBinding(DefaultParameterSetName = 'Standard')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Standard')]
        [Parameter(Mandatory, ParameterSetName = 'Warning')]
        [Parameter(Mandatory, ParameterSetName = 'Critical')]
        [string] $Message,

        [Parameter(ParameterSetName = 'Warning')]
        [switch] $Warning,

        [Parameter(ParameterSetName = 'Critical')]
        [switch] $Critical,

        [Parameter(Mandatory, ParameterSetName = 'InputObject')]
        [ScriptMessage] $InputObject
    )
    begin {
        function Get-AnsiForegroundCode {
            [CmdletBinding()]
            [OutputType([int])]
            param(
                [Parameter(Mandatory)]
                [string] $Name
            )
            begin {
                $defaultAnsiForegroundCode = 39
                $brightRedAnsiForegroundCode = 91
                $brightYellowAnsiForegroundCode = 93
            }
            process {
                switch ($Name) {
                    'Warning' { $brightYellowAnsiForegroundCode }
                    'Critical' { $brightRedAnsiForegroundCode }
                    default { $defaultAnsiForegroundCode }
                }
            }
        }
    }
    process {
        $displayMessage = $Message
        $ansiForegroundCode = switch ($PSCmdlet.ParameterSetName) {
            'InputObject' {
                $displayMessage = $InputObject.Content
                Get-AnsiForegroundCode -Name $InputObject.Level
            }
            default { Get-AnsiForegroundCode -Name $PSCmdlet.ParameterSetName }
        }

        Write-Host "`e[${ansiForegroundCode}m$displayMessage`e[${defaultForegroundCode}m"
    }
}

$rootPath = (git -C $Path rev-parse --show-toplevel 2> $null) ?? $Path

$argumentsFileName = 'ef.args'
$configurationArgumentsPath = Join-Path -Path $rootPath -ChildPath '.config' -AdditionalChildPath $argumentsFileName
$rootArgumentsPath = Join-Path -Path $rootPath -ChildPath ".$argumentsFileName"
$argumentsFile = (Get-Item -Path $configurationArgumentsPath -ErrorAction SilentlyContinue) `
    ?? (Get-Item -Path $rootArgumentsPath -ErrorAction SilentlyContinue)
$arguments = $null -ne $argumentsFile ? (& $env:BIN/parse-key-values.ps1 -Path $argumentsFile.FullName) : @{}

$parameterDefinitionProperties = @(
    @{ Name = 'Name'; Expression = { $_.name }},
    @{ Name = 'Description'; Expression = { $_.description.Text }},
    @{ Name = 'DefaultValue'; Expression = { $_.defaultValue }},
    @{ Name = 'DirectoryValue'; Expression = { $arguments[$_.name] }},
    @{ Name = 'BoundValue'; Expression = { $PSBoundParameters[$_.name] } }
)
$parameterDefinitions = Get-Help -Name $MyInvocation.MyCommand.Source -Detailed |
    Select-Object -ExpandProperty 'parameters' |
    Select-Object -ExpandProperty 'parameter' |
    Select-Object -Property $parameterDefinitionProperties

$arguments.GetEnumerator() |
    ForEach-Object {
        $matchingParameterDefinition = $parameterDefinitions |
            Where-Object -Property Name -EQ $_.Key
        if (-not $matchingParameterDefinition) {
            $argumentsRelativePath = Resolve-Path -Path $argumentsFile -Relative -RelativeBasePath $rootPath
            $message = "The $($_.Key) argument in '$argumentsRelativePath' has no matching parameter and will be ignored."
            Show-ScriptMessage -Message $message -Warning
            return
        }

        if ($null -eq $matchingParameterDefinition.BoundValue -and
            $null -ne $matchingParameterDefinition.DirectoryValue) {
            Set-Variable -Name $_.Key -Value $matchingParameterDefinition.DirectoryValue -Scope Script
        }
    }

$projectPath = Join-Path -Path $rootPath -ChildPath $Project
$startupPath = Join-Path -Path $rootPath -ChildPath $StartupProject
$connection = [System.Environment]::GetEnvironmentVariable($ConnectionVariable)

function New-DotnetToolScript {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [string] $Command,

        [Parameter()]
        [string] $Argument,

        [Parameter()]
        [string[]] $Option = @()
    )
    process {
        $toolCommand = "dotnet ef $Command"
        if ($Argument) {
            $toolCommand += " $Argument"
        }

        $segments = @(
            $toolCommand,
            "--project '$projectPath'",
            "--startup-project '$startupPath'",
            "--configuration '$BuildConfiguration'"
        )

        if (-not $IncludeBuild) {
            $segments += '--no-build'
        }

        $segments += $Option
        [scriptblock]::Create($segments -join ' ')
    }
}

$invalidActionMessage = "The provided '$Action' action is not supported."

function Get-ScriptHelp {
    [CmdletBinding()]
    [OutputType([ScriptMessage])]
    param(
        [Parameter()]
        [string] $Action
    )
    begin {
        $boldFormat = "`e[1m{0}`e[22m"
        $underlineFormat = "`e[4m{0}`e[24m"
    }
    process {
        $messageBuilder = [System.Text.StringBuilder]::new()

        if (-not $Action) {
            $keyPaddingLength = ($parameterDefinitions |
                Select-Object -ExpandProperty Name |
                Measure-Object -Property Length -Maximum |
                Select-Object -ExpandProperty Maximum) + 1
            [void]$messageBuilder.AppendLine($underlineFormat -f 'ACTIONS')
            $actionDefinitions |
                ForEach-Object {
                    $actionKey = $boldFormat -f ($_.Key.PadRight($keyPaddingLength, ' '))
                    [void]$messageBuilder.AppendLine("  $actionKey $($_.Description)")
                }

            [void]$messageBuilder.AppendLine()
            [void]$messageBuilder.AppendLine($underlineFormat -f 'PARAMETERS')
            $parameterDefinitions |
                ForEach-Object {
                    $parameterName = $boldFormat -f ($_.Name.PadRight($keyPaddingLength, ' '))
                    [void]$messageBuilder.AppendLine("  $parameterName $($_.Description)")
                }
        } else {
            $actionDefinition = $actionDefinitions |
                Where-Object -Property Key -EQ $Action
            if (-not $actionDefinition) {
                return [ScriptMessage]::new($invalidActionMessage, [ScriptMessageLevel]::Critical)
            }

            [void]$messageBuilder.AppendLine($underlineFormat -f $Action)
            $messageLines = [ordered]@{
                Description = $actionDefinition.Description
            }

            if ($actionDefinition.NameUsage) {
                $messageLines['Name Usage'] = $actionDefinition.NameUsage
                $messageLines['Name Required'] = $actionDefinition.NameRequired
            }

            if ($actionDefinition.ConnectionUsage) {
                $messageLines['Connection Usage'] = $actionDefinition.ConnectionUsage
                $messageLines['Connection Required'] = $actionDefinition.ConnectionRequired
            }

            $keyPaddingLength = ($messageLines.GetEnumerator() |
                Select-Object -ExpandProperty Key |
                Measure-Object -Property Length -Maximum |
                Select-Object -ExpandProperty Maximum) + 1
            $messageLines.GetEnumerator() |
                ForEach-Object {
                    $keyDisplay = $boldFormat -f $_.Key
                    $keyPadding = ''.PadRight($keyPaddingLength - $_.Key.Length, ' ')
                    [void]$messageBuilder.AppendLine("  $keyDisplay$keyPadding $($_.Value)")
                }
        }

        return [ScriptMessage]::new($messageBuilder.ToString(), [ScriptMessageLevel]::Standard)
    }
}

$addAction = 'add'
$applyAction = 'apply'
$bundleAction = 'bundle'
$changesAction = 'changes'
$contextAction = 'context'
$helpAction = 'help'
$listAction = 'list'
$removeAction = 'remove'
$scriptAction = 'script'

$actionDefinitions = @(
    @{
        Key = $addAction
        Description = 'Adds a new migration.'
        NameRequired = $true
        NameUsage = 'The name of the migration to add.'
        ConnectionRequired = $false
        ScriptBuilder = {
            New-DotnetToolScript -Command 'migrations add' -Argument $Name
        }
    },
    @{
        Key = $applyAction
        Description = 'Applies migrations to the database directly.'
        NameRequired = $false
        NameUsage = 'The name of the migration to apply.'
        ConnectionRequired = $true
        ConnectionUsage = 'The database connection to apply migrations to.'
        ScriptBuilder = {
            $arguments = @{
                Command = 'database update'
            }

            if ($Name) {
                $arguments['Argument'] = $Name
            }

            if ($connection) {
                $arguments['Option'] = "--connection '$connection'"
            }

            New-DotnetToolScript @arguments
        }
    },
    @{
        Key = $bundleAction
        Description = 'Executes the bundle to apply migrations to the database.'
        NameRequired = $false
        NameUsage = 'The name of the migration to apply.'
        ConnectionRequired = $true
        ConnectionUsage = 'The database connection to apply migrations to.'
        ScriptBuilder = {
            $bundlePath = Join-Path -Path $rootPath -ChildPath $BundleDirectory -AdditionalChildPath 'efbundle.exe'
            $segments = @($bundlePath)

            if ($connection) {
                $segments += ,"--connection '$connection'"
            }

            if ($Name) {
                $segments += $Name
            }

            [scriptblock]::Create("$segments")
        }
    },
    @{
        Key = $changesAction
        Description = 'Checks for model changes not represented in a migration.'
        NameRequired = $false
        ConnectionRequired = $false
        ScriptBuilder = {
            New-DotnetToolScript -Command 'migrations has-pending-model-changes'
        }
    },
    @{
        Key = $contextAction
        Description = 'Display information about the application database context.'
        NameRequired = $false
        ConnectionRequired = $false
        ScriptBuilder = {
            New-DotnetToolScript -Command 'dbcontext info'
        }
    },
    @{
        Key = $helpAction
        AlternateKey = ''
        Description = 'Displays help messages for the script or for an action.'
        NameRequired = $false
        NameUsage = 'The action to view help for.'
        ConnectionRequired = $false
        ScriptBuilder = {
            $message = Get-ScriptHelp -Action $Name
            Show-ScriptMessage -InputObject $message

            $exitCode = $Action ? 0 : 2
            [scriptblock]::Create("exit $exitCode")
        }
    },
    @{
        Key = $listAction
        Description = 'Lists available migrations.'
        NameRequired = $false
        ConnectionRequired = $false
        ConnectionUsage = 'The database connection to list migrations from.'
        ScriptBuilder = {
            $arguments = @{
                Command = 'migrations list'
            }

            if ($connection) {
                $arguments['Option'] = "--connection '$connection'"
            }

            New-DotnetToolScript @arguments
        }
    },
    @{
        Key = $removeAction
        Description = 'Removes the latest migration.'
        NameRequired = $false
        ConnectionRequired = $false
        ScriptBuilder = {
            New-DotnetToolScript -Command 'migrations remove'
        }
    },
    @{
        Key = $scriptAction
        Description = 'Generates a script to apply migrations to the database.'
        NameRequired = $false
        NameUsage = 'The name of the latest migration to apply or a range of migrations in the format "<FROM>..<TO>".'
        ConnectionRequired = $false
        ScriptBuilder = {
            $arguments = @{
                Command = 'migrations script'
                Option = '--idempotent'
            }

            if ($Name) {
                $rangeSeparator = '..'
                $rangeSeparatorIndex = $Name.IndexOf($rangeSeparator)
                if ($rangeSeparatorIndex -eq -1) {
                    $arguments['Argument'] = "'0' '$Name'"
                } else {
                    $fromName = $Name.Substring(0, $rangeSeparatorIndex)
                    $toName = $Name.Substring($rangeSeparatorIndex + $rangeSeparator.Length)
                    $arguments['Argument'] = "'$fromName' '$toName'"
                }
            }

            New-DotnetToolScript @arguments
        }
    }
)

$selectedActionDefinition = $actionDefinitions |
    Where-Object {
        $_.Key -eq $Action -or
        ($null -ne $_.AlternateKey -and $_.AlternateKey -eq $Action)
    }
if ($null -eq $selectedActionDefinition) {
    Show-ScriptMessage -Message $invalidActionMessage -Critical
    exit 1
}

$nameParameterDefinition = $parameterDefinitions |
    Where-Object -Property Name -EQ 'Name'
if ($selectedActionDefinition.NameRequired -and -not $Name) {
    Show-ScriptMessage -Message "Name is required for the $Action action." -Critical
    exit 1
} elseif ($nameParameterDefinition.BoundValue -and -not $selectedActionDefinition.NameUsage) {
    Show-ScriptMessage -Message "Name is not used for the $Action action. The provided value '$Name' will be ignored." -Warning
}

$connectionVariableParameterDefinition = $parameterDefinitions |
    Where-Object -Property Name -EQ 'ConnectionVariable'
$connectionVariableParameterBound = $null -ne $connectionVariableParameterDefinition.BoundValue
$connectionVariableParameterProvided = $connectionVariableParameterBound -or
    $null -ne $connectionVariableParameterDefinition.DirectoryValue
$connectionEmptyMessageSuffix = "but the '$ConnectionVariable' environment variable does not have a value set"
if ($selectedActionDefinition.ConnectionRequired -and -not $connection) {
    $baseMessage = "ConnectionVariable is required for the $Action action"
    $message = -not $ConnectionVariable `
        ? "$baseMessage." `
        : "$baseMessage $connectionEmptyMessageSuffix."
    Show-ScriptMessage -Message $message -Critical
    exit 1
} elseif ($connectionVariableParameterProvided -and -not $connection -and $null -ne $selectedActionDefinition.ConnectionUsage) {
    Show-ScriptMessage -Message "ConnectionVariable provided $connectionEmptyMessageSuffix." -Warning
} elseif ($connectionVariableParameterBound -and -not $selectedActionDefinition.ConnectionUsage) {
    $message = "ConnectionVariable is not used for the $Action action. The provided value '$ConnectionVariable' will be ignored."
    Show-ScriptMessage -Message $message -Warning
}

$actionScript = Invoke-Command -ScriptBlock $selectedActionDefinition.ScriptBuilder
Write-Verbose "Executing ``$actionScript``."
Invoke-Command -ScriptBlock $actionScript
