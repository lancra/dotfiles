[CmdletBinding()]
param(
    [Parameter()]
    [string] $Directory = "$env:APPDATA/Mozilla/Firefox"
    )

$lines = Get-Content -Path "$Directory/profiles.ini"
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if (-not ($line.StartsWith('[Install'))) {
        continue
    }

    $prefix = 'Default='
    for ($j = $i + 1; $j -lt $lines.Length; $j++) {
        $line = $lines[$j]
        if (-not ($line.StartsWith($prefix))) {
            continue
        }

        $relativePath = $line.TrimStart($prefix)
        return "$Directory/$relativePath" -replace '\\', '/'
    }
}
