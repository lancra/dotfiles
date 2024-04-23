[CmdletBinding()]
param (
    [Parameter()]
    [string]$Name = 'mssql',
    [switch]$PullImage,
    [switch]$Force
)

$image = 'mcr.microsoft.com/mssql/server:2022-latest'
$port = 1433

if ($PullImage) {
    & podman pull $image
}

& podman container exists $Name
$containerExists = $LASTEXITCODE -eq 0
if ($containerExists) {
    if ($Force) {
        Write-Verbose 'Removing existing container.'
        & podman container rm --force $Name | Out-Null
    } else {
        Write-Verbose 'Starting existing container.'
        & podman container start $Name
        exit 0
    }
}

if (-not $msSqlPassword) {
    $msSqlPassword = Read-Host -Prompt 'Password' -MaskInput
}

$runArguments = @(
    '--env', 'ACCEPT_EULA=Y',
    '--env', "MSSQL_SA_PASSWORD=$msSqlPassword",
    '--publish', "${port}:$port",
    '--name', $Name,
    '--hostname', $Name,
    '--detach',
    $image
)
Write-Verbose 'Running container.'
& podman run @runArguments | Out-Null

Write-Verbose 'Creating sqlcmd context.'
& sqlcmd config get-contexts --name $Name 2>&1> $null
$hasContext = $LASTEXITCODE -eq 0
if ($hasContext) {
    & sqlcmd config delete-context --name $Name --cascade 2>&1> $null
}

& sqlcmd config add-endpoint --name $Name --address 127.0.0.1 --port $port 2>&1> $null

$env:SQLCMD_PASSWORD = $msSqlPassword
& sqlcmd config add-user --name $Name --username sa --password-encryption dpapi 2>&1> $null
$env:SQLCMD_PASSWORD = $null

& sqlcmd config add-context --name $Name --endpoint $Name --user $Name 2>&1> $null
