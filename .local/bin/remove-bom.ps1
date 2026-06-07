<#
.SYNOPSIS
Removes the UTF-8 byte order mark from a file.

.DESCRIPTION
The first three bytes of the file are read to determine if a byte order mark is
present. If so, the remaining bytes are written to the file.

.PARAMETER Path
The path of the file to modify.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

$byteOrderMark = @(0xEF, 0xBB, 0xBF)

$file = Get-Item -Path $Path -ErrorAction SilentlyContinue
if ($null -eq $file) {
    throw "No file was found at '$Path'."
} elseif ($file.PSIsContainer) {
    throw "Unable to operate on directory at '$Path'."
}

$bytes = [System.IO.File]::ReadAllBytes($Path)

for ($i = 0; $i -lt $byteOrderMark.Length; $i++) {
    if ($bytes[$i] -ne $byteOrderMark[$i]) {
        Write-Verbose "No UTF-8 byte order mark was found."
        exit
    }
}

[System.IO.File]::WriteAllBytes($Path, $bytes[3..$bytes.Length])
