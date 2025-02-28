<#
.SYNOPSIS
Displays information about PowerShell commands and aliases.

.DESCRIPTION
When the provided name is an alias, help is provided for the alias definition.
Otherwise, help is provided using the normal mechanism.

.PARAMETER Name
Gets help about the specified command or alias.

.NOTES
Provides a workaround for PowerShell not resolving alias definitions unless the
associated script is located in the PATH.

See: https://github.com/PowerShell/PowerShell/issues/2899
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Name
)

$alias = Get-Alias -Name $Name -ErrorAction SilentlyContinue
if ($alias) {
    Get-Help -Name $alias.Definition
} else {
    Get-Help -Name $Name
}
