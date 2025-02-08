[CmdletBinding()]
param(
    [Parameter()]
    [int] $Count = 1
)

$segments = @()

for ($i = 0; $i -lt $Count; $i++) {
    $segments += '..'
}

$path = $segments -join '/'
Set-Location -Path $path
