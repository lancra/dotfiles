<#
.SYNOPSIS
Displays information about PowerShell commands and aliases.

.DESCRIPTION
When the provided name is an alias, help is provided for the alias definition.
Otherwise, help is provided using the normal mechanism.

.PARAMETER Name
Gets help about the specified command or alias.

.PARAMETER Detailed
Adds parameter descriptions and examples to the basic help display.

.PARAMETER Full
Displays the entire help article for a cmdlet. Full includes parameter
descriptions and attributes, examples, input and output object types, and
additional notes.

.PARAMETER Parameter
Displays only the detailed descriptions of the specified parameters. Wildcards
are permitted.

.LINK
Issue: https://github.com/PowerShell/PowerShell/issues/2899

.NOTES
Provides a workaround for PowerShell not resolving alias definitions unless the
associated script is located in the PATH.
#>
# NOTE: A non-breaking space is used between the key and URI in the .LINK
#       section to avoid duplication in the Get-Help output.
#       See: https://redirect.github.com/PowerShell/PowerShell/issues/24504
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
    [string] $Name,

    [Parameter(ParameterSetName = 'Detailed')]
    [switch] $Detailed,

    [Parameter(ParameterSetName = 'Full')]
    [switch] $Full,

    [Parameter(Mandatory, ParameterSetName = 'Parameter')]
    [string] $Parameter
)

$alias = Get-Alias -Name $Name -ErrorAction SilentlyContinue
$arguments = @{
    Name = $alias ? $alias.Definition : $Name
}

if ($PSCmdlet.ParameterSetName -eq 'Detailed') {
    $arguments['Detailed'] = $Detailed
} elseif ($PSCmdlet.ParameterSetName -eq 'Full') {
    $arguments['Full'] = $Full
} elseif ($PSCmdlet.ParameterSetName -eq 'Parameter') {
    $arguments['Parameter'] = $Parameter
}

Get-Help @arguments
