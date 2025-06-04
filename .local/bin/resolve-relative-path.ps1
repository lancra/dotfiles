<#
.SYNOPSIS
Resolves an absolute path from a path.

.DESCRIPTION
Iterates through each segment in a provided path to convert it into an absolute
path. The working directory is used to resolve provided relative paths. This
script handles paths for non-existent filesystem items.

.PARAMETER Path
The path to resolve.
#>
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
