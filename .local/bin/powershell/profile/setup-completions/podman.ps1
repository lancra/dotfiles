$script = & podman completion powershell
$script += "Register-ArgumentCompleter -CommandName 'pm' -ScriptBlock `${__podmanCompleterBlock}"
$script | Out-String | Invoke-Expression
