[CmdletBinding()]
param()

Get-Content -Path "$PSScriptRoot/providers.json" | jq -r '.providers.[] | .id'
