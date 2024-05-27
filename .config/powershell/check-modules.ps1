[CmdletBinding()]
param()

Get-InstalledModule |
    ForEach-Object {
        $latestModule = Find-Module -Name $_.Name -Repository $_.Repository
        if ($latestModule.Version -ne $_.Version) {
            [ordered]@{
                provider = 'powershell'
                id = $_.Name
                current = $_.Version
                available = $latestModule.Version
            }
        }
    } |
    ConvertTo-Json -AsArray
