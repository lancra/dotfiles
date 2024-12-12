[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Id
)

& go install "$Id@latest"
