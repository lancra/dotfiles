$setupCompletion = & podman completion powershell | Out-String
$setupCompletion += "`nRegister-ArgumentCompleter -CommandName 'pm' -ScriptBlock `${__podmanCompleterBlock}"
$setupCompletion | Invoke-Expression
