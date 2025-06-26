[CmdletBinding()]
param()

Get-ChildItem -Path "$env:XDG_DATA_HOME/machine" -Directory |
    Select-Object -ExpandProperty Name
