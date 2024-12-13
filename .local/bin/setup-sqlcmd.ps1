[CmdletBinding()]
param ()

$executableDirectory = "$env:PROGRAMFILES\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"
$executableSymlink = "$executableDirectory\LSQLCMD.EXE"
if (-not (Test-Path -Path $executableSymlink)) {
    New-Item -ItemType SymbolicLink -Path $executableSymlink -Target "$executableDirectory\SQLCMD.EXE"
}

$resourceLibraryDirectory = "$executableDirectory\Resources\1033"
$resourceLibrarySymlink = "$resourceLibraryDirectory\LSQLCMD.rll"
if (-not (Test-Path -Path $resourceLibrarySymlink)) {
    New-Item -ItemType SymbolicLink -Path $resourceLibrarySymlink -Target "$resourceLibraryDirectory\SQLCMD.rll"
}
