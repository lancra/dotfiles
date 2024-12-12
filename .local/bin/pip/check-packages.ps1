[CmdletBinding()]
param()

& pip list --not-required --outdated --format json |
    ConvertFrom-Json |
    ForEach-Object {
        [ordered]@{
            provider = 'pip'
            id = $_.name
            current = $_.version
            available = $_.latest_version
        }
    } |
    ConvertTo-Json -AsArray
