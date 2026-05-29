[CmdletBinding()]
param()

function Get-CargoIndexPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Id
    )
    process {
        # See: https://doc.rust-lang.org/cargo/reference/registry-index.html#index-files
        $indexPathPrefix = switch ($Id.Length) {
            1 { '1' }
            2 { '2' }
            3 { "3/$($Id.Substring(0, 1))" }
            default { "$($Id.Substring(0, 2))/$($Id.Substring(2, 2))" }
        }

        return "$indexPathPrefix/$Id"
    }
}

$getCargoIndexDefinition = ${function:Get-CargoIndexPath}.ToString()

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
            ${function:Get-CargoIndexPath} = $using:getCargoIndexDefinition

            $source = "https://crates.io/crates/$($crate.Id)"
            $indexPath = Get-CargoIndexPath -Id $crate.Id

            $prereleaseFilter = { $null -ne ($_.vers -as [version]) }
            $crateDetails = @{
                $descriptionProperty = & cargo info --quiet "$($crate.Id)" |
                    Select-Object -Skip 1 -First 1
                $availableProperty = & curl --silent "https://index.crates.io/$indexPath" |
                    ForEach-Object {
                        $_ |
                            ConvertFrom-Json
                    } |
                    Where-Object $prereleaseFilter |
                    Sort-Object -Property { $_.vers -as [version] } |
                    Select-Object -Last 1 |
                    Select-Object -ExpandProperty 'vers'
            }
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
