# PowerShell parameter completion shim for the dotnet CLI
@('dotnet', 'd') |
    ForEach-Object {
        Register-ArgumentCompleter -Native -CommandName $_ -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
                dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
