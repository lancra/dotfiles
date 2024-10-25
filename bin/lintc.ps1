[CmdletBinding()]
param (
    [Parameter()]
    [string]$Path = '.'
)

function Write-LintResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [int]$Code
    )

    Write-Host "${Name}: " -NoNewline
    if ($Code -eq 0) {
        Write-Host 'Succeeded' -ForegroundColor 'Green'
    } else {
        Write-Host 'Failed' -ForegroundColor 'Red'
    }
}

Write-Host 'Executing markdownlint...'
& markdownlint $Path
$markdownlintCode = $LASTEXITCODE

Write-Host 'Executing prettier...'
& prettier --check $Path
$prettierCode = $LASTEXITCODE

Write-Host 'Executing yamllint...'
& yamllint --strict $Path
$yamllintCode = $LASTEXITCODE

Write-Host ''
Write-LintResult -Name 'markdownlint' -Code $markdownlintCode
Write-LintResult -Name 'prettier' -Code $prettierCode
Write-LintResult -Name 'yamllint' -Code $yamllintCode

$overallCode = $markdownlintCode + $prettierCode + $yamllintCode -ne 0 ? 1 : 0
exit $overallCode
