[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Value,

    [switch] $Machine,

    [switch] $Force
)

$key = $Machine ? 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' : 'HKCU\Environment'
$arguments = @(
    'REG',
    'DELETE',
    "`"$key`"",
    "/V $Value"
)

if ($Force) {
    $arguments += '/F'
}

$arguments -join ' ' |
    Invoke-Expression
