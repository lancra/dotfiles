[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string] $Source = "$env:XDG_CONFIG_HOME/vscode/settings/mssql.connections.json"
)

enum AuthenticationType {
    AzureMFA
    Integrated
    SqlLogin
}

function Get-HashGuid {
    [CmdletBinding()]
    [OutputType([guid])]
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )
    process {
        try {
            $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
            $stream = [System.IO.MemoryStream]::new($valueBytes)
            $hash = Get-FileHash -InputStream $stream -Algorithm SHA256 |
                Select-Object -ExpandProperty Hash
            return [Guid]::new($hash[0..31] -join '')
        }
        finally {
            if ($stream) {
                $stream.Dispose()
            }
        }
    }
}

$azureTenants = @{}
$azureUsers = @{}

function Get-AzureTenantId {
    [CmdletBinding()]
    [OutputType([guid])]
    param(
        [Parameter(Mandatory)]
        [string] $Domain
    )
    process {
        $cachedTenantId = $azureTenants[$Domain]
        if ($cachedTenantId) {
            return $cachedTenantId
        }

        $issuer = [uri](curl --silent "https://login.microsoftonline.com/$Domain/.well-known/openid-configuration" |
            ConvertFrom-Json |
            Select-Object -ExpandProperty 'issuer')
        $tenantId = [guid]($issuer.Segments[1].TrimEnd('/'))
        $azureTenants[$Domain] = $tenantId
        return $tenantId
    }
}

function Get-AzureUserId {
    [CmdletBinding()]
    [OutputType([guid])]
    param(
        [Parameter(Mandatory)]
        [string] $UserPrincipalName
    )
    process {
        $cachedUserId = $azureUsers[$UserPrincipalName]
        if ($cachedUserId) {
            return $cachedUserId
        }

        $userId = [guid](& az ad user show --id $UserPrincipalName |
            ConvertFrom-Json |
            Select-Object -ExpandProperty 'id')
        $azureUsers[$UserPrincipalName] = $userId
        return $userId
    }
}

$schemaProperty = '$schema'
$groupCounter = 1
$groups = @()
$connections = @()
(Get-Content -Path $Source |
    ConvertFrom-Json).PSObject.Properties |
    ForEach-Object {
        if ($_.Name -eq $schemaProperty) {
            return
        }

        $group = [pscustomobject]@{
            name = $_.Name
            id = Get-HashGuid -Value $_.Name
            color = $_.Value.color
        }

        if ($_.Value.parent -ne $_.Name) {
            $parentId = $groups |
                Where-Object -Property 'id' -EQ $_.Value.parent
            $group |
                Add-Member -MemberType NoteProperty -Name 'parentId' -Value $parentId

            $group.name = "$groupCounter $($group.name)"
            $groupCounter++
        }

        $prefix = $_.Value.prefix ?? $_.Name[0]

        $groups += ,$group
        $_.Value.connections.PSObject.Properties |
            ForEach-Object {
                $authentication = [AuthenticationType]$_.Value.authentication
                $profileName = $_.Name
                if ($prefix) {
                    $profileName = "$prefix.$($_.Name)"
                }

                $connection = [pscustomobject]@{
                    applicationIntent = $_.Value.intent
                    applicationName = 'vscode-mssql'
                    authenticationType = $authentication.ToString()
                    commandTimeout = 30
                    connectTimeout = 30
                    database = $_.Value.database
                    encrypt = 'Mandatory'
                    groupId = $group.id
                    id = Get-HashGuid -Value $profileName
                    password = ''
                    profileName = $profileName
                    profileSource = 0
                    server = $_.Value.server
                    trustServerCertificate = $true
                    user = ''
                }

                if ($authentication -eq [AuthenticationType]::AzureMFA) {
                    $userPrincipalName = $_.Value.user
                    $connection |
                        Add-Member -MemberType NoteProperty -Name 'email' -Value $userPrincipalName

                    $userId = Get-AzureUserId -UserPrincipalName $userPrincipalName
                    $domain = $userPrincipalName.Substring($userPrincipalName.IndexOf('@') + 1)
                    $tenantId = Get-AzureTenantId -Domain $domain
                    $connection |
                        Add-Member -MemberType NoteProperty -Name 'accountId' -Value "$userId.$tenantId"

                    $connection |
                        Add-Member -MemberType NoteProperty -Name 'azureAccountToken' -Value ''
                } elseif ($authentication -eq [AuthenticationType]::SqlLogin) {
                    $connection.user = $_.Value.user

                    $connection |
                        Add-Member -MemberType NoteProperty -Name 'emptyPasswordInput' -Value $false

                    $connection |
                        Add-Member -MemberType NoteProperty -Name 'savePassword' -Value $true
                }

                $connections += ,$connection
            }
    }

$settings = [pscustomobject]@{
    'mssql.connectionGroups' = $groups
    'mssql.connections' = $connections
}

$settings |
    ConvertTo-Json
