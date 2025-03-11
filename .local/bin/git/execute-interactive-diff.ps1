[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path,

    [switch] $Staged
)

class Selection {
    [char] $Code
    [string] $Description
    [scriptblock] $Command

    Selection([char] $code, [string] $description, [scriptblock] $command) {
        $this.Code = $code
        $this.Description = $description
        $this.Command = $command
    }
}

class CommandBuilder {
    [string] $Command
    [string[]] $Options
    [string] $Path

    CommandBuilder([string] $command, [string] $path) {
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

function Get-Selection {
    [CmdletBinding()]
    [OutputType([Selection])]
    param(
        [Parameter(Mandatory)]
        [Selection[]] $Selections
    )
    begin {
        $selectionCodes = $Selections | ForEach-Object { $_.Code }
        $selectionCodesDisplay = $selectionCodes -join ','
    }
    process {
        $selection = $null
        while ($null -eq $selection) {
            $selection = Read-Host "Handle differences [$selectionCodesDisplay]"

            if (-not $selection) {
                $selection = $null
                continue
            }

            if ($selection.Length -gt 1) {
                Write-Host "Only one letter is expected, got '$selection'" -ForegroundColor Red
                $selection = $null
                continue
            }

            $matchingSelection = $Selections |
                Where-Object { $_.Code -eq $selection }
            if ($null -eq $matchingSelection) {
                Write-Host "Unknown command '$selection' (use '?' for help)" -ForegroundColor Red
                $selection = $null
                continue
            }
        }

        return $matchingSelection
    }
}

# REMOVE: Verify parameters.
Write-Output "Path='$Path'"
Write-Output "Staged='$Staged'"
Write-Output ''

$gitPath = $Path ? $Path : '.'

$statusCommandBuilder = [CommandBuilder]::new('status', $gitPath)
$statusCommandBuilder.AddOption('--short')
$statusCommand = $statusCommandBuilder.Build()

$statusResultLines = Invoke-Command -ScriptBlock $statusCommand
$statusResults = [StatusResult]::FromOutput($statusResultLines)

# REMOVE: Verify status.
Write-Output "Status='$statusCommand'"
foreach ($statusResult in $statusResults) {
    Write-Output "LeftCode='$($statusResult.LeftCode)' RightCode='$($statusResult.RightCode)' Path='$($statusResult.Path)'"
}

$selections = -not $Staged ?
    @(
        [Selection]::new('a', 'add changes to the index', { & git add $gitPath }),
        [Selection]::new('f', 'restore fragment of changes from the working directory', { & git restore --patch $gitPath }),
        [Selection]::new('p', 'patch changes to the index', { & git add --patch $gitPath }),
        [Selection]::new('r', 'restore changes from the working directory', { & git restore $gitPath })
    ) :
    @(
        [Selection]::new('f', 'restore fragment of changes from the index', { & git restore --staged --patch $gitPath }),
        [Selection]::new('r', 'restore changes from the index', { & git restore --staged $gitPath })
    )
$selections += @(
    [Selection]::new('s', 'split changes by file', {}),
    [Selection]::new('q', 'quit', {}),
    [Selection]::new(
        '?',
        'print help',
        {
            $selections |
                ForEach-Object {
                    Write-Output "$($_.Code) - $($_.Description)"
                }
        })
)

$diffCommandBuilder = [CommandBuilder]::new('diff', $gitPath)
$diffCommandBuilder.AddOptionIf('--staged', $Staged)

$diffCommand = $diffCommandBuilder.Build()
$diffQuietCommand = $diffCommandBuilder.Build('--quiet')

Invoke-Command -ScriptBlock $diffCommand
Invoke-Command -ScriptBlock $diffQuietCommand
$hasDifferences = $LASTEXITCODE -ne 0

if ($hasDifferences) {
    Write-Output ''
    $selection = $null
    while ($null -eq $selection) {
        $selection = Get-Selection -Selections $selections
        Invoke-Command -ScriptBlock $selection.Command

        if ($selection.Code -eq '?') {
            $selection = $null
        }
    }
}
