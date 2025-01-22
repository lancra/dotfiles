[console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

Set-PSReadLineOption -EditMode Vi -ViModeIndicator Cursor
Set-PSReadLineKeyHandler -Key '*,y' -BriefDescription 'global yank' -ViMode Command -Scriptblock {
    param($key, $arg)
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    Set-Clipboard $line
}

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
        dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# dotnet suggest shell start
if (Get-Command "dotnet-suggest" -errorAction SilentlyContinue)
{
    $availableToComplete = (dotnet-suggest list) | Out-String
    $availableToCompleteArray = $availableToComplete.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)

    Register-ArgumentCompleter -Native -CommandName $availableToCompleteArray -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $fullpath = (Get-Command $commandAst.CommandElements[0]).Source

        $arguments = $commandAst.Extent.ToString().Replace('"', '\"')
        dotnet-suggest get -e $fullpath --position $cursorPosition -- "$arguments" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
else
{
    "Unable to provide System.CommandLine tab completion support unless the [dotnet-suggest] tool is first installed."
    "See the following for tool installation: https://www.nuget.org/packages/dotnet-suggest"
}

$env:DOTNET_SUGGEST_SCRIPT_VERSION = "1.0.2"
# dotnet suggest script end

Import-Module 'Lance'

Import-Module HackF5.ProfileAlias
$profileAliasesPath = Join-Path -Path $env:XDG_CONFIG_HOME -ChildPath 'powershell' -AdditionalChildPath 'aliases.json'
Get-Content -Path $profileAliasesPath |
    ConvertFrom-Json |
    ForEach-Object {
        $bash = [bool]::Parse($_.bash)
        Set-ProfileAlias -Name $_.name -Command $_.command -Bash:$bash -Force | Out-Null
    }

Import-Module 'posh-git'
oh-my-posh init pwsh --config "$env:XDG_CONFIG_HOME/powershell/lancra.omp.json" | Invoke-Expression
