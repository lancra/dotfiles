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
