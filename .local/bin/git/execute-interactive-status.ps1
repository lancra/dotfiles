[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path
)

<#
global
---
a - add
b - break
d - diff [index/working directory]
f - fragmental restore [index/working directory]
p - patch {if untracked, add intent then patch}
r - restore [index/working directory]
s - status
q - quit
? - help

file
---
a - add
d - diff [index/working directory]
f - fragmental restore [index/working directory] {index should also restore working directory adds (intents)}
n - nothing
p - patch {if untracked, add intent then patch}
r - restore [index/working directory] {index should also restore working directory adds (intents)}
q - quit
? - help
#>

$redTextFormat = "`e[31m{0}`e[0m"
$greenTextFormat = "`e[32m{0}`e[0m"

class StatusResult {
    [StatusFile[]] $Files
    [bool] $HasChanges

    StatusResult([StatusFile[]] $files) {
        $this.Files = $files
        $this.HasChanges = $files.Length -gt 0
    }

    [string] GetOutput() {
        $builder = [System.Text.StringBuilder]::new()
        $this.Files |
            ForEach-Object {
                [void]$builder.AppendLine($_.GetOutput())
            }

        return $builder.ToString()
    }

    static [StatusResult] Get([string] $targetPath) {
        $statusFiles = @()

        $lines = & git status --short $targetPath
        if ($lines) {
            $statusFiles = $lines |
                ForEach-Object {
                    [StatusFile]::FromGitLine($_)
                }
        }

        return [StatusResult]::new($statusFiles)
    }
}

class StatusFile {
    [char] $LeftCode
    [char] $RightCode
    [string] $Path

    StatusFile([char] $leftCode, [char] $rightCode, [string] $path) {
        $this.LeftCode = $leftCode
        $this.RightCode = $rightCode
        $this.Path = $path
    }

    [string] GetOutput() {
        $leftCodeOutput = $this.LeftCode -in @('A', 'M') `
            ? $script:greenTextFormat -f $this.LeftCode `
            : $script:redTextFormat -f $this.LeftCode
        $rightCodeOutput = $script:redTextFormat -f $this.RightCode

        return "$leftCodeOutput$rightCodeOutput $($this.Path)"
    }

    static [StatusFile] FromGitLine([string] $line) {
        $left = $line[0]
        $right = $line[1]
        $filePath = $line.Substring(3)
        return [StatusFile]::new($left, $right, $filePath)
    }
}

enum OperationMode {
    Global
    File
}

enum OperationArea {
    # Working directory is specified first since it's the typical default.
    WorkingDirectory
    Index
}

class Operation {
    [scriptblock] $Command
    [string] $Code
    [string] $Description
    [OperationMode[]] $Modes
    [OperationArea[]] $Areas

    Operation([string] $code, [string] $description, [OperationMode[]] $modes, [scriptblock] $command) {
        $this.Code = $code
        $this.Command = $command
        $this.Description = $description
        $this.Modes = $modes
        $this.Areas = @()
    }

    Operation([scriptblock] $command, [string] $code, [string] $description, [OperationMode[]] $modes, [OperationArea[]] $areas) {
        $this.Command = $command
        $this.Code = $code
        $this.Description = $description
        $this.Modes = $modes
        $this.Areas = $areas
    }

    static [Operation] Message([string] $code, [scriptblock] $command) {
        return New-Operation -Command $command -Code $code
    }
}

function New-Operation {
    [CmdletBinding()]
    [OutputType([Operation])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $Command,

        [Parameter()]
        [string] $Code = '',

        [Parameter()]
        [string] $Description = '',

        [Parameter()]
        [OperationMode[]] $Mode = [OperationMode].GetEnumValues(),

        [Parameter()]
        [OperationArea[]] $Area = @()
    )
    process {
        [Operation]::new($Command, $Code, $Description, $Mode, $Area)
    }
}

class OperationContext {
    [string] $Path
    [Operation[]] $AvailableOperations
    [Operation] $Operation
    [bool] $Exit
    [int] $ExitCode

    OperationContext([string] $path, [Operation[]] $availableOperations) {
        $this.Path = $path
        $this.AvailableOperations = $availableOperations
        $this.Exit = $false
        $this.ExitCode = 0
    }
}

function Build-Operations {
    [CmdletBinding()]
    [OutputType([Operation[]])]
    param(
        [Parameter(Mandatory)]
        [OperationMode] $Mode
    )
    process {
        $operations = @()

        # TODO: Toggle each operation by StatusResult (e.g. add hidden when no changes in working directory).
        $addOperation = @{
            Command = {
                param([OperationContext] $context)
                & git add $context.Path
                $context.Exit = $true
            }
            Code = 'a'
            Description = 'add changes to the index'
        }
        $operations += New-Operation @addOperation

        $breakOperation = @{
            Command = {
                param([OperationContext] $context)
                # TODO
                $context.Exit = $true
            }
            Code = 'b'
            Description = 'break changes into separate files'
            Mode = @([OperationMode]::Global)
        }
        $operations += New-Operation @breakOperation

        $diffOperation = @{
            Command = {
                param([OperationContext] $context)
                & git diff $context.Path
                $context.Exit = $true
            }
            Code = 'd'
            Description = 'view differences'
        }
        $operations += New-Operation @diffOperation

        $fragmentalRestoreOperation = @{
            Command = {
                param([OperationContext] $context)
                & git restore --patch $context.Path
                $context.Exit = $true
            }
            Code = 'f'
            Description = 'restore fragment of changes'
        }
        $operations += New-Operation @fragmentalRestoreOperation

        $nothingOperation = @{
            Command = {
                param([OperationContext] $context)
                $context.Exit = $true
            }
            Code = 'n'
            Description = 'perform no action on the file'
            Mode = @([OperationMode]::File)
        }
        $operations += New-Operation @nothingOperation

        $patchOperation = @{
            Command = {
                param([OperationContext] $context)
                & git add --patch $context.Path
                $context.Exit = $true
            }
            Code = 'p'
            Description = 'patch changes to the index'
        }
        $operations += New-Operation @patchOperation

        $restoreOperation = @{
            Command = {
                param([OperationContext] $context)
                & git restore $context.Path
                $context.Exit = $true
            }
            Code = 'r'
            Description = 'restore changes'
        }
        $operations += New-Operation @restoreOperation

        $statusOperation = @{
            Command = {
                param([OperationContext] $context)
                & git status --short $context.Path
            }
            Code = 's'
            Description = 'show status'
            Mode = @([OperationMode]::Global)
        }
        $operations += New-Operation @statusOperation

        $quitOperation = @{
            Command = {
                param([OperationContext] $context)
                $context.Exit = $true
            }
            Code = 'q'
            Description = 'quit'
        }
        $operations += New-Operation @quitOperation

        $helpOperation = @{
            Command = {
                param([OperationContext] $context)
                $context.AvailableOperations |
                    ForEach-Object {
                        Write-Output "$($_.Code) - $($_.Description)"
                    }
            }
            Code = '?'
            Description = 'print help'
        }
        $operations += New-Operation @helpOperation

        $operations |
            Where-Object { $_.Modes.Contains($Mode) }
    }
}

function Read-Operation {
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
        $operationInput = Read-Host "Perform operation [$codesDisplay]"

        if (-not $operationInput) {
            return [Operation]::Message($operationInput, {})
        }

        # TODO: Move below operation match, since d,f,r allow an area specification.
        if ($operationInput.Length -gt 1) {
            return [Operation]::Message(
                $operationInput,
                {
                    param([OperationContext] $context)
                    Write-Output ($redTextFormat -f "Only one letter is expected, got '$($context.Operation.Code)'")
                }
            )
        }

        $operation = $Operations |
            Where-Object { $_.Code -eq $operationInput }
        if ($null -eq $operation) {
            return [Operation]::Message(
                $operationInput,
                {
                    param([OperationContext] $context)
                    Write-Output ($redTextFormat -f "Unknown command '$($context.Operation.Code)' (use '?' for help)")
                }
            )
        }

        return $operation
    }
}

$gitPath = $Path ? $Path : '.'
$statusResult = [StatusResult]::Get($gitPath)
Write-Output $statusResult.GetOutput()

if ($statusResult.HasChanges) {
    $globalOperations = Build-Operations -Mode ([OperationMode]::Global)
    $context = [OperationContext]::new($gitPath, $globalOperations)

    while (-not $context.Exit) {
        $context.Operation = Read-Operation -Operations $context.AvailableOperations
        Invoke-Command -ScriptBlock $context.Operation.Command -ArgumentList $context
    }

    if ($context.Exit) {
        exit $context.ExitCode
    }
}
