[CmdletBinding()]
param()

& cargo install --list |
    ForEach-Object {
        if ($_[0] -ne ' ') {
            $crateParts = $_ -split ' '
            [ordered]@{
                Id = $crateParts[0]
                Current = $crateParts[1].TrimStart('v').TrimEnd(':')
            }
        }
    } |
    ForEach-Object -Parallel {
        $crateDetails = & curl --silent "https://crates.io/api/v1/crates/$($_.Id)" |
            ConvertFrom-Json |
            Select-Object -ExpandProperty crate
        @{
            Id = $_.Id
            Description = $crateDetails.description
            Current = $_.Current
            Available = $crateDetails.max_stable_version ?? $_.Current
        }
    } |
    Sort-Object -Property Id
