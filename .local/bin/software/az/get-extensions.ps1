[CmdletBinding()]
param()

try {
    $availableJob = Start-ThreadJob -ScriptBlock {
        & az extension list-available |
            ConvertFrom-Json
    }

    $installedJob = Start-ThreadJob -ScriptBlock {
        & az extension list |
            ConvertFrom-Json
    }

    $jobs = @($availableJob, $installedJob)
    $jobs |
        Wait-Job |
        Out-Null

    $availableExtensions = Receive-Job -Job $availableJob
    $installedExtensions = Receive-Job -Job $installedJob
}
finally {
    Remove-Job -Job $jobs
}

$installedExtensions |
    ForEach-Object {
        $availableExtension = $availableExtensions |
            Where-Object -Property 'name' -EQ $_.name

        @{
            Id = $_.name
            Description = $availableExtension.summary
            Preview = $_.preview
            Experimental = $_.experimental
            Current = $_.version
            Available = $availableExtension.version
        }
    } |
    Sort-Object -Property Id
