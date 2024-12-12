[CmdletBinding()]
param()

(& npm outdated -g --json |
    & jq 'to_entries | map({id: .key, current: .value.current, available: .value.latest})' |
    ConvertFrom-Json |
    ForEach-Object {
        [ordered]@{
            provider = 'npm'
            id = $_.id
            current = $_.current
            available = $_.available
        }
    } |
    ConvertTo-Json -AsArray) 2> $null
