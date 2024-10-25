[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Path,
    [switch]$Format
)

$configurationPath = "$env:XDG_CONFIG_HOME/sqlfluff/tsql.sqlfluff"
$action = $Format ? 'format' : 'lint'

& sqlfluff $action --config $configurationPath $Path
