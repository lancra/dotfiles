[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

$sentinelPath = Join-Path -Path $env:HOME -ChildPath '.dotnet' -AdditionalChildPath "$(& dotnet --version).dotnetFirstUseSentinel"
if (-not (Test-Path -Path $sentinelPath)) {
    # If the first use sentinel for the current SDK version is not present, it prepends the output with a welcome message and breaks
    # the export process.
    New-Item -Path $sentinelPath | Out-Null
}

& dotnet tool list --global |
    ForEach-Object {
        if ($_.StartsWith('Package Id') -or $_.StartsWith('---')) {
            return
        }

        $spaceIndex = $_.IndexOf(' ')
        $id = $_.Substring(0, $spaceIndex)
        [ordered]@{
            Id = $id
            Url = "https://nuget.org/packages/$id"
        }
    } |
    Sort-Object -Property Id |
    ConvertTo-Csv -UseQuotes AsNeeded |
    Set-Content -Path $Target
