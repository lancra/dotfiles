[CmdletBinding()]
param()

$configurationDirectory = "$env:XDG_CONFIG_HOME/software"
$ignoredRepositories = (Get-Content -Path "$configurationDirectory/.ignored.podman-images.json" -ErrorAction SilentlyContinue |
    ConvertFrom-Json) ?? @()
$includedRepositories = (Get-Content -Path "$configurationDirectory/.included.podman-images.json" -ErrorAction SilentlyContinue |
    ConvertFrom-Json) ?? @()

$repositoryIgnorePatterns = @(
    '<none>',
    'localhost\/.*'
)

& podman images --format '{{ json . }}' |
    ForEach-Object {
        $_ |
            ConvertFrom-Json
    } |
    Where-Object { $includedRepositories.Length -eq 0 -or $includedRepositories -contains $_.repository } |
    Where-Object {
        $includedRepositories.Length -gt 0 -or $ignoredRepositories.Length -eq 0 -or $ignoredRepositories -notcontains $_.repository
    } |
    ForEach-Object {
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

        $id = "$($_.repository):$($_.tag)"
        $repositorySegments = & "$PSScriptRoot/parse-image-id.ps1" -Id $id

        @{
            Id = $id
            Registry = $repositorySegments.Registry
            Namespace = $repositorySegments.Namespace
            Repository = $repositorySegments.Repository
            Tag = $repositorySegments.Tag
            Digest = $_.Digest
            Architecture = $_.Arch
            OperatingSystem = $_.Os
        }
    } |
    Sort-Object -Property Id
