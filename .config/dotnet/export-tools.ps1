[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$Target
)

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
