[CmdletBinding()]
param()

& podman images --format '{{ json . }}' |
    ForEach-Object {
        $_ |
            ConvertFrom-Json
    } |
    ForEach-Object {
        if ($_.repository.StartsWith('localhost/')) {
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
