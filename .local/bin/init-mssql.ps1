<#
.SYNOPSIS
Initializes a Microsoft SQL Server container and enables usage in SQLCMD.

.DESCRIPTION
Checks for an existing container by the provided name, and throws an error by
default or removes it when executing forcefully. Then, using the password
provided via a local variable or by manual input, a new container is initialized
and started. Finally, a SQLCMD context is optionally configured for usage.

.PARAMETER Name
The name of the container to create.

.PARAMETER Image
The image to use when creating the container. When this parameter is not
provided, the latest SQL Server image is used.

.PARAMETER Port
The port to bind the container to. When this parameter is not provided, the
default SQL Server port of 1433 is used.

.PARAMETER ContextName
The name of the SQLCMD context to create. When this parameter is not provided,
the container name is used.

.PARAMETER Force
Specifies that an existing container with the same name should first be removed.

.PARAMETER SkipContext
Specifies that the SQLCMD context should not be set up.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Name = 'mssql',

    [Parameter()]
    [string] $Image = 'mcr.microsoft.com/mssql/server:2025-latest',

    [Parameter()]
    [int] $Port,

    [Parameter()]
    [string] $ContextName = $Name,

    [switch]$Force,

    [switch]$SkipContext
)

$containerPort = 1433
if (-not $Port) {
    $Port = $containerPort
}

& podman container exists $Name
$containerExists = $LASTEXITCODE -eq 0
if ($containerExists) {
    if ($Force) {
        Write-Verbose 'Removing existing container.'
        & podman container rm --force $Name | Out-Null
    } else {
        Write-Error "The $Name container already exists. Run with -Force to ovwerwrite it."
        exit 1
    }
}

if ($msSqlPassword) {
    Write-Verbose 'Found password, skipping entry.'
} else {
    $msSqlPasswordEntry = Read-Host 'Server Administrator Password' -AsSecureString
    $msSqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($msSqlPasswordEntry))
}

$runArguments = @(
    '--env', 'ACCEPT_EULA=Y',
    '--env', "MSSQL_SA_PASSWORD=$msSqlPassword",
    '--publish', "${Port}:$containerPort",
    '--name', $Name,
    '--detach',
    $Image
)
Write-Verbose 'Running container.'
& podman run @runArguments | Out-Null

if (-not $SkipContext) {
    Write-Verbose 'Creating sqlcmd context.'
    & sqlcmd config get-contexts --name $ContextName 2>&1> $null
    $hasContext = $LASTEXITCODE -eq 0
    if ($hasContext) {
        & sqlcmd config delete-context --name $ContextName --cascade 2>&1> $null
    }

    & sqlcmd config add-endpoint --name $ContextName --address 127.0.0.1 --port $Port 2>&1> $null

    $oldSqlcmdPassword = $env:SQLCMD_PASSWORD
    $env:SQLCMD_PASSWORD = $msSqlPassword
    & sqlcmd config add-user --name $ContextName --username sa --password-encryption dpapi 2>&1> $null
    $env:SQLCMD_PASSWORD = $oldSqlcmdPassword

    & sqlcmd config add-context --name $ContextName --endpoint $ContextName --user $ContextName 2>&1> $null
}
