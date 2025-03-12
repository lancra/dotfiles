[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path,

    [switch] $Staged
)

class GitCommandBuilder {
    [string] $Command
    [string[]] $Options
    [string] $Path

    GitCommandBuilder([string] $command, [string] $path) {
        $this.Command = $command
        $this.Options = @()
        $this.Path = $path
    }

    [void] AddOption([string] $option) {
        $this.Options += $option
    }

    [void] AddOptionIf([string] $option, [bool] $condition) {
        if ($condition) {
            $this.AddOption($option)
        }
    }

    [scriptblock] Build() {
        return $this.Build(@())
    }

    [scriptblock] Build([string[]] $additionalOptions) {
        $buildOptions = @()
        $buildOptions = $buildOptions + $this.Options
        $buildOptions += $additionalOptions

        $commandText = "git $($this.Command) $($buildOptions -join ' ')"
        if ($this.Path) {
            $commandText += " $($this.Path)"
        }
        return [scriptblock]::Create($commandText)
    }
}

class StatusResult {
    [char] $LeftCode
    [char] $RightCode
    [string] $Path

    StatusResult([char] $leftCode, [char] $rightCode, [string] $path) {
        $this.LeftCode = $this.ToCode($leftCode)
        $this.RightCode = $this.ToCode($rightCode)
        $this.Path = $path
    }

    [char] ToCode([char] $character) {
        if ($character -eq ' ') {
            return "`0"
        }

        return $character
    }

    static [StatusResult[]] FromOutput([string[]] $output) {
        if (-not $output) {
            return @()
        }

        return $output |
            ForEach-Object {
                $leftCode = $_[0]
                $rightCode = $_[1]
                $path = $_.Substring(3)
                [StatusResult]::new($leftCode, $rightCode, $path)
            }
    }
}

class Operation {
    [char] $Code
    [string] $Description
    [bool] $Actionable
    [scriptblock] $Command

    Operation([char] $code, [string] $description, [bool] $actionable, [scriptblock] $command) {
        $this.Code = $code
        $this.Description = $description
        $this.Actionable = $actionable
        $this.Command = $command
    }
}

class OperationContext {
    [string] $Path
    [Operation[]] $Operations
    [bool] $Exit
    [int] $ExitCode

    OperationContext([string] $path, [Operation[]] $operations) {
        $this.Path = $path
        $this.Operations = $operations
        $this.Exit = $false
        $this.ExitCode = 0
    }
}

function Build-Operations {
    [CmdletBinding()]
    [OutputType([Operation[]])]
    param()
    process {
        $operations = -not $Staged ?
            @(
                [Operation]::new(
                    'a',
                    'add changes to the index',
                    $true,
                    {
                        param([OperationContext] $context)
                        & git add $context.Path
                        $context.Exit = $true
                    }
                ),
                [Operation]::new(
                    'f',
                    'restore fragment of changes from the working directory',
                    $true,
                    {
                        param([OperationContext] $context)
                        & git restore --patch $context.Path
                        $context.Exit = $true
                    }
                ),
                [Operation]::new(
                    'p',
                    'patch changes to the index',
                    $true,
                    {
                        param([OperationContext] $context)
                        & git add --patch $context.Path
                        $context.Exit = $true
                    }
                ),
                [Operation]::new(
                    'r',
                    'restore changes from the working directory',
                    $true,
                    {
                        param([OperationContext] $context)
                        & git restore $context.Path
                        $context.Exit = $true
                    }
                )
            ) :
            @(
                [Operation]::new(
                    'f',
                    'restore fragment of changes from the index',
                    $true,
                    {
                        param([OperationContext] $context)
                        & git restore --staged --patch $context.Path
                        $context.Exit = $true
                    }
                ),
                [Operation]::new(
                    'r',
                    'restore changes from the index',
                    $true,
                    {
                        param([OperationContext] $context)
                        & git restore --staged $context.Path
                        $context.Exit = $true
                    }
                )
            )

        $operations += @(
            [Operation]::new(
                'b',
                'break changes into separate files',
                $true,
                {
                    param([OperationContext] $context)
                    # TODO
                    $context.Exit = $true
                }
            ),
            [Operation]::new(
                's',
                'show status',
                $true,
                {
                    param([OperationContext] $context)
                    & git status --short $context.Path
                    $context.Exit = $false
                }
            )
            [Operation]::new(
                'q',
                'quit',
                $false,
                {
                    param([OperationContext] $context)
                    $context.Exit = $true
                }
            ),
            [Operation]::new(
                '?',
                'print help',
                $false,
                {
                    param([OperationContext] $context)
                    $context.Operations |
                        ForEach-Object {
                            Write-Output "$($_.Code) - $($_.Description)"
                        }

                    $context.Exit = $false
                }
            )
        )

        $operations |
            Sort-Object -Property @(
                @{ Expression = { -not $_.Actionable } },
                @{ Expression = { $_.Code -notmatch '[A-Za-z]' } },
                @{ Expression = { $_.Code } }
            )
    }
}

function Get-Operation {
    [CmdletBinding()]
    [OutputType([Operation])]
    param(
        [Parameter(Mandatory)]
        [Operation[]] $Operations
    )
    begin {
        $codes = $Operations | ForEach-Object { $_.Code }
        $codesDisplay = $codes -join ','
    }
    process {
        $operation = $null
        while ($null -eq $operation) {
            $operation = Read-Host "Handle differences [$codesDisplay]"

            if (-not $operation) {
                $operation = $null
                continue
            }

            if ($operation.Length -gt 1) {
                Write-Host "Only one letter is expected, got '$operation'" -ForegroundColor Red
                $operation = $null
                continue
            }

            $matchingOperation = $Operations |
                Where-Object { $_.Code -eq $operation }
            if ($null -eq $matchingOperation) {
                Write-Host "Unknown command '$operation' (use '?' for help)" -ForegroundColor Red
                $operation = $null
                continue
            }
        }

        return $matchingOperation
    }
}

# REMOVE: Verify parameters.
Write-Output "Path='$Path'"
Write-Output "Staged='$Staged'"
Write-Output ''

$gitPath = $Path ? $Path : '.'

$statusCommandBuilder = [GitCommandBuilder]::new('status', $gitPath)
$statusCommandBuilder.AddOption('--short')
$statusCommand = $statusCommandBuilder.Build()

$statusResultLines = Invoke-Command -ScriptBlock $statusCommand
$statusResults = [StatusResult]::FromOutput($statusResultLines)

# REMOVE: Verify status.
Write-Output "Status='$statusCommand'"
foreach ($statusResult in $statusResults) {
    Write-Output "LeftCode='$($statusResult.LeftCode)' RightCode='$($statusResult.RightCode)' Path='$($statusResult.Path)'"
}

$diffCommandBuilder = [GitCommandBuilder]::new('diff', $gitPath)
$diffCommandBuilder.AddOptionIf('--staged', $Staged)

$diffCommand = $diffCommandBuilder.Build()
$diffQuietCommand = $diffCommandBuilder.Build('--quiet')

Invoke-Command -ScriptBlock $diffCommand
Invoke-Command -ScriptBlock $diffQuietCommand
$hasDifferences = $LASTEXITCODE -ne 0

if ($hasDifferences) {
    Write-Output ''

    $operation = $null
    $context = [OperationContext]::new($gitPath, (Build-Operations))
    while (-not $context.Exit) {
        $operation = Get-Operation -Operations $context.Operations
        Invoke-Command -ScriptBlock $operation.Command -ArgumentList $context
    }

    if ($context.Exit) {
        exit $context.ExitCode
    }
}
