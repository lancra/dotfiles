[CmdletBinding()]
param ()

& $PSScriptRoot/get-packages.ps1 |
    ForEach-Object {
        $module = "$($_.Path)@latest"
        $newVersion = & go list -m -f "{{.Version}}" $module
        if ($_.Version -ne $newVersion) {
            [ordered]@{
                provider = 'go'
                id = $_.Id
                current = $_.Version.TrimStart('v')
                available = $newVersion.TrimStart('v')
            }
        }
    } |
    ConvertTo-Json -AsArray
