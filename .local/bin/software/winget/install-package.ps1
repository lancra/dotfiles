[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

$idParts = $Id.Split('@')
$name = $idParts[0]
$source = $idParts[1]

& winget install --exact --id $name --source $source
