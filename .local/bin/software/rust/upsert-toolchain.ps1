[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

& rustup toolchain install $Id
