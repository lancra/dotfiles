[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

function Get-PathParts {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        $Path.Replace('\', '/').Split('/')
    }
}

$parts = Get-PathParts -Path $Path
if ($parts[0] -match '.:') {
    return $Path
}

$relativePathParts = Get-PathParts -Path $PWD
$parts |
    ForEach-Object {
        if ($_ -eq '.') {
            return
        }

        if ($_ -eq '..' -and $relativePathParts.Count -gt 1) {
            $relativePathParts = $relativePathParts[0..($relativePathParts.Length - 2)]
            return
        }

        $relativePathParts += $_
    }

$relativePathParts -join '/'
