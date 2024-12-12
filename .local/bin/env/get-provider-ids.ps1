[CmdletBinding()]
param()

Get-Content -Path "$env:XDG_CONFIG_HOME/env/providers.json" | jq -r '.providers.[] | .id'
