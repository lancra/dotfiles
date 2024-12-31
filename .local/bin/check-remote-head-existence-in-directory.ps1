[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = '.'
)

Get-ChildItem -Path $Path -Directory |
    ForEach-Object {
        $repositoryName = [System.IO.Path]::GetFileName($_)
        Write-Host "${repositoryName}: " -NoNewline

        $gitDirectory = Join-Path -Path $_ -ChildPath '.git'
        if (-not (Test-Path -Path $gitDirectory)) {
            Write-Host 'Uninitialized' -ForegroundColor 'Yellow'
            return
        }

        $originRemotePath = Join-Path -Path $gitDirectory -ChildPath 'refs' -AdditionalChildPath 'remotes', 'origin'
        if (-not (Test-Path -Path $originRemotePath)) {
            Write-Host 'Local' -ForegroundColor 'Magenta'
            return
        }

        $originRemoteHeadPath = Join-Path -Path $originRemotePath -ChildPath 'HEAD'
        $hasRemoteHead = Test-Path -Path $originRemoteHeadPath

        if ($hasRemoteHead) {
            Write-Host 'Present' -ForegroundColor 'Green'
        } else {
            Write-Host 'Missing' -ForegroundColor 'Red'
        }
    }
