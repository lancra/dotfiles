[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [uri] $Repository
)

$segments = $Repository |
    Select-Object -ExpandProperty Segments |
    Select-Object -Last 2
$id = $segments -join ''

$idSuffix = '.git'
if ($id.EndsWith($idSuffix)) {
    $id = $id.Substring(0, $id.Length - $idSuffix.Length)
}

$id
