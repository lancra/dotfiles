[CmdletBinding()]
param()

$ignoredRepositories = @()
$ignoredRepositoriesPath = "$env:XDG_CONFIG_HOME/software/.ignored.podman-images.json"
if (Test-Path -Path $ignoredRepositoriesPath) {
    $ignoredRepositories = Get-Content -Path $env:XDG_CONFIG_HOME/software/.ignored.podman-images.json |
        ConvertFrom-Json
}

$repositoryIgnorePatterns = @(
    '<none>',
    'localhost\/.*'
)

& podman images --format '{{ json . }}' |
    ForEach-Object {
        $_ |
            ConvertFrom-Json
    } |
    ForEach-Object {
        if ($ignoredRepositories -contains $_.repository) {
            return
        }

        $ignoreRepositoryFromPattern = $false
        foreach ($pattern in $repositoryIgnorePatterns) {
            if ($_.repository -match $pattern) {
                $ignoreRepositoryFromPattern = $true
                break
            }
        }

        if ($ignoreRepositoryFromPattern) {
            return
        }

        $parts = $_.repository.Split('/')
        $registry = $parts[0]

        if ($registry -eq 'mcr.microsoft.com') {
            $namespace = ''
            $repository = [string]::Join('/', $parts[1..($parts.Length - 1)])
        } else {
            $namespace = $parts[1]
            $repository = [string]::Join('/', $parts[2..($parts.Length - 1)])
        }

        @{
            Id = "$($_.repository):$($_.tag)"
            Registry = $parts[0]
            Namespace = $namespace
            Repository = $repository
            Tag = $_.tag
            Digest = $_.Digest
            Architecture = $_.Arch
            OperatingSystem = $_.Os
        }
    } |
    Sort-Object -Property Id
