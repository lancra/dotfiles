using module ../software.psm1

[CmdletBinding()]
param()

$sentinelPath = Join-Path -Path $env:HOME -ChildPath '.dotnet' -AdditionalChildPath "$(& dotnet --version).dotnetFirstUseSentinel"
if (-not (Test-Path -Path $sentinelPath)) {
    # If the first use sentinel for the current SDK version is not present, it prepends the output with a welcome message and breaks
    # the export process.
    New-Item -Path $sentinelPath | Out-Null
}

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

& dotnet tool list --global |
    ForEach-Object {
        if ($_.StartsWith('Package Id') -or $_.StartsWith('---')) {
            return
        }

        $spaceIndex = $_.IndexOf(' ')
        $toolId = $_.Substring(0, $spaceIndex)
        $id = [InstallationId]::new($toolId, $exportId)
        $metadata = [ordered]@{
            Url = "https://nuget.org/packages/$toolId"
        }

        [Installation]::new($id, $metadata)
    }
