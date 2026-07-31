[CmdletBinding(SupportsShouldProcess)]
param()

function Get-GitHubFileContent {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Repository,

        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        $uri = "/repos/$Repository/contents/$Path"
        $contentBase64 = & gh api $uri |
            ConvertFrom-Json |
            Select-Object -ExpandProperty 'content'
        $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($contentBase64))

        # GitHub (git) returns LF delimited content while PowerShell expects CRLF.
        $lines = $content -split "`n"
        return $lines[0..($lines.Count - 2)]
    }
}

Get-Content -Path "$env:XDG_CONFIG_HOME/catppuccin/configuration.json" |
    ConvertFrom-Json |
    ForEach-Object {
        try {
            $remoteContent = Get-GitHubFileContent -Repository $_.repository -Path $_.source
            $remotePath = [System.IO.Path]::GetTempFileName()
            $remoteContent |
                Set-Content -Path $remotePath -WhatIf:$false

            & git diff --exit-code --no-patch --no-index -- $_.file $remotePath
            $hasChanges = $LASTEXITCODE -ne 0
        }
        finally {
            if ($remotePath) {
                Remove-Item -Path $remotePath -WhatIf:$false | Out-Null
            }
        }

        if (-not $hasChanges) {
            Write-Output "$($PSStyle.Foreground.BrightGreen)No changes found for $($_.name).$($PSStyle.Reset)"
            return
        }

        Write-Output "$($PSStyle.Foreground.BrightRed)Changes found for $($_.name).$($PSStyle.Reset)"
        if ($PSCmdlet.ShouldProcess($_.file, 'Set-Content')) {
            Set-Content -Path $_.file -Value $remoteContent
        }
    }
