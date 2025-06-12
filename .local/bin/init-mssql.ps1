[CmdletBinding()]
param (
    [Parameter()]
    [string] $Name = 'mssql',
    [Parameter()]
    [string] $Image = 'mcr.microsoft.com/mssql/server:2022-latest',
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
