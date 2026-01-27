$script = & dotnet completions script pwsh
$script | Out-String | Invoke-Expression

$registerLineFormat = "Register-ArgumentCompleter -Native -CommandName '{0}' -ScriptBlock {{"
$registerLineIndex = $script.IndexOf(($registerLineFormat -f 'dotnet'))
if ($registerLineIndex -eq -1) {
    $message = 'Unable to find the .NET argument completer registration line. ' + `
        'This is required to setup completions for the command alias. ' + `
        'Review the output of `dotnet completion script pwsh`.'
    Write-Warning $message
    return
}


$script[$registerLineIndex] = ($registerLineFormat -f 'd')
$script | Out-String | Invoke-Expression
