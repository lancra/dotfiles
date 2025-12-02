[CmdletBinding()]
param()

& cargo install --list |
    ForEach-Object {
        if ($_[0] -ne ' ') {
            $crateParts = $_ -split ' '

            $repository = $null
            if ($crateParts.Length -eq 3) {
                $installUri = [Uri]::new($crateParts[2].TrimStart('(').TrimEnd(':').TrimEnd(')'))
                $repository = "$($installUri.Scheme)://$($installUri.Host)$($installUri.AbsolutePath)"
            }

            [ordered]@{
                Id = $crateParts[0]
                Current = $crateParts[1].TrimStart('v').TrimEnd(':')
                Repository = $repository
            }
        }
    } |
    ForEach-Object -Parallel {
        $crate = $_

        $descriptionProperty = 'Description'
        $availableProperty = 'Available'

        $fromRegistry = $null -eq $crate.Repository
        if ($fromRegistry) {
            $source = "https://crates.io/crates/$($crate.Id)"
            $registryProperties = @(
                @{Name = $descriptionProperty; Expression = {$_.description}},
                @{Name = $availableProperty; Expression = {$_.max_stable_version ?? $crate.Current}}
            )
            $crateDetails = & curl --silent "https://crates.io/api/v1/crates/$($crate.Id)" |
                ConvertFrom-Json |
                Select-Object -ExpandProperty crate |
                Select-Object -Property $registryProperties
        } else {
            $source = $_.Repository
            $repository = [Uri]::new($_.Repository)
            $repositoryId = & "$env:BIN/git/get-repository-id.ps1" -Repository $repository

            $crateDetails = @{
                $descriptionProperty = & gh repo view $repositoryId --json description |
                    ConvertFrom-Json |
                    Select-Object -ExpandProperty description
                $availableProperty = & "$env:BIN/git/get-latest-remote-tag.ps1" -Repository $repository |
                    ForEach-Object { $_.TrimStart('v')
                }
            }
        }

        @{
            Id = $source
            Name = $crate.Id
            Description = $crateDetails.Description
            Current = $crate.Current
            Available = $crateDetails.Available
        }
    } |
    Sort-Object -Property Id
