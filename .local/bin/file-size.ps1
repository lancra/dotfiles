<#
.SYNOPSIS
Displays a user-friendly size for all relevant files in a tabular format.

.DESCRIPTION
Determines the target paths to show based on the provided path. For each target
path, the right-aligned count is shown, then the right-aligned denomination is
shown, followed by the left-aligned name. The smallest possible denomination is
used where the whole number is limited to three digits.

.PARAMETER Path
The path to display sizes for. When a directory is provided, the sizes of all
children are shown. When a file is provided, the size of it is shown. When this
is not provided, the working directory is used.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter()]
    [string] $Path = '.'
)

$item = Get-Item -Path $Path -ErrorAction SilentlyContinue
$targetPaths = @($Path)
if ($null -eq $item) {
    throw 'The provided path is invalid.'
} elseif ($item -is [System.IO.DirectoryInfo]) {
    $absolutePath = Resolve-Path -Path $Path
    $targetPaths = Get-ChildItem -Path $item.FullName -File |
        Select-Object -ExpandProperty FullName |
        ForEach-Object { [System.IO.Path]::GetRelativePath($absolutePath, $_) }
}

$targetPaths |
    ForEach-Object {
        $bytes = Get-Item -Path $_ |
            Select-Object -ExpandProperty Length
        $size = & "$PSScriptRoot/get-byte-size.ps1" -Count $bytes -Format 'padded'
        "`e[93m$size`e[39m $_"
    }
