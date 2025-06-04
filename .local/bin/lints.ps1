<#
.SYNOPSIS
Lints all SQL files matching the provided path with SQLFluff.

.DESCRIPTION
Using the T-SQL configuration, executes either the lint or format command with
SQLFluff on the provided path.

.PARAMETER Path
The path to lint. If a file is provided, linting is performed on it alone. If a
directory is provided, linting is provided on all SQL files recursively
contained within it.

.PARAMETER Format
When set, SQLFluff will perform in-place changes to correct linting issues.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $Path,

    [switch] $Format
)

$configurationPath = "$env:XDG_CONFIG_HOME/sqlfluff/tsql.sqlfluff"
$action = $Format ? 'format' : 'lint'

& sqlfluff $action --config $configurationPath $Path
