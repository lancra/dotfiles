[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript({
        $_ -in (Get-Content -Path $exportsPath | jq -r '.[] | .id')},
        ErrorMessage = 'The provided export was not found.')]
    [ArgumentCompleter({
        param($cmd, $param, $wordToComplete)
        if ($param -eq 'Export') {
            $validExports = @(Get-Content -Path $exportsPath | jq -r '.[] | .id')
            $validExports -like "$wordToComplete*"
        }
    })]
    [string]$Export
)
begin {
    function Publish-Export {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]$Name,
            [Parameter(Mandatory)]
            [string]$Path
        )
        process {
            Write-Host "Exporting $Name..." -NoNewline
            & $Path
            Write-Host 'Done'
        }
    }

    $exportsPath = "$env:XDG_CONFIG_HOME/lancra/env/exports.json"

    $beginLoading = "`e]9;4;3`a"
    $endLoading = "`e]9;4;0`a"

    Write-Host $beginLoading -NoNewline
}
process {
    $exports = Get-Content -Path $exportsPath |
        ConvertFrom-Json

    $targetExports = $exports
    if ($Export) {
        $targetExports = $exports |
            Where-Object -Property id -EQ $Export
    }

    $targetExports |
        ForEach-Object {
            Publish-Export -Name $_.name -Path $_.path
        }
}
end {
    Write-Host $endLoading -NoNewline
}
