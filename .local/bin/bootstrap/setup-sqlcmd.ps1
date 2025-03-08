[CmdletBinding()]
param ()

function Write-SetupOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $InputObject
    )
    process {
        Write-Output "sqlcmd: $InputObject"
    }
}

$executableDirectory = "$env:PROGRAMFILES\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"
$executableSymlink = "$executableDirectory\LSQLCMD.EXE"

$resourceLibraryDirectory = "$executableDirectory\Resources\1033"
$resourceLibrarySymlink = "$resourceLibraryDirectory\LSQLCMD.rll"

$sourcePaths = @($executableSymlink, $resourceLibrarySymlink)

$linkChecks = @{}
$sourcePaths |
    ForEach-Object {
        $pathExists = Test-Path -Path $_
        $isLink = $pathExists -and (is-link.ps1 -Path $_)
        $linkChecks[$_] = $isLink
    }

$anyMissingLinks = ($linkChecks.GetEnumerator() |
    Where-Object { -not $_.Value }).Length -ne 0

if (-not $anyMissingLinks) {
    Write-SetupOutput 'Links have already been established.'
    exit 0
}

if (-not $linkChecks[$executableSymlink]) {
    Remove-Item -Path $executableSymlink -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $executableSymlink -Target "$executableDirectory\SQLCMD.EXE"

    Write-SetupOutput 'Link established for executable.'
}

if (-not $linkChecks[$resourceLibrarySymlink]) {
    Remove-Item -Path $resourceLibrarySymlink -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType SymbolicLink -Path $resourceLibrarySymlink -Target "$resourceLibraryDirectory\SQLCMD.rll"

    Write-SetupOutput 'Link established for resource library.'
}
