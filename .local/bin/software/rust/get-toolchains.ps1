[CmdletBinding()]
param()

$idGroup = 'id'
$versionGroup = 'version'
$toolchainRegex = "(?<$idGroup>.*?) - (?<status>.*?) : (?<$versionGroup>.*)"

$channelGroup = 'channel'
$environmentGroup = 'environment'
$idRegex = "(?<$channelGroup>.*?)-(?<host>(?<architecture>.*?)-(?<operating_system>.*)-(?<$environmentGroup>.*))"

$currentVersionGroup = 'current_version'
$currentCommitGroup = 'current_commit'
$currentDateGroup = 'current_date'
$availableVersionGroup = 'available_version'
$availableCommitGroup = 'available_commit'
$availableDateGroup = 'available_date'

$currentRegex = "(?<$currentVersionGroup>.*?) \((?<$currentCommitGroup>.*?) (?<$currentDateGroup>.*?)\)"
$availableRegex = "(?<$availableVersionGroup>.*?) \((?<$availableCommitGroup>.*?) (?<$availableDateGroup>.*?)\)"
$versionRegex = "$currentRegex( -> $availableRegex)?"

$channelSorting = @('stable', 'beta', 'nightly')

function Get-GroupValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.MatchInfo] $Match,

        [Parameter(Mandatory)]
        [string] $Group
    )
    process {
        $Match.Matches.Groups |
            Where-Object -Property Name -EQ $Group |
            Select-Object -ExpandProperty Value
    }
}

& rustup check |
    ForEach-Object {
        $toolchainMatch = $_ | Select-String -Pattern $toolchainRegex

        $id = Get-GroupValue -Match $toolchainMatch -Group $idGroup
        $version = Get-GroupValue -Match $toolchainMatch -Group $versionGroup
        if ($id -eq 'rustup') {
            # WinGet is responsible for rustup versioning.
            return
        }

        $idMatch = $id | Select-String -Pattern $idRegex
        $channel = Get-GroupValue -Match $idMatch -Group $channelGroup
        $environment = Get-GroupValue -Match $idMatch -Group $environmentGroup

        $versionMatch = $version | Select-String -Pattern $versionRegex
        $currentVersion = Get-GroupValue -Match $versionMatch -Group $currentVersionGroup
        $currentCommit = Get-GroupValue -Match $versionMatch -Group $currentCommitGroup
        $currentDate = Get-GroupValue -Match $versionMatch -Group $currentDateGroup
        $availableVersion = Get-GroupValue -Match $versionMatch -Group $availableVersionGroup
        $availableCommit = Get-GroupValue -Match $versionMatch -Group $availableCommitGroup
        $availableDate = Get-GroupValue -Match $versionMatch -Group $availableDateGroup

        @{
            Id = $id
            Name = "$channel ($environment)"
            Channel = $channel
            Environment = $environment
            Current = $currentVersion
            CurrentCommit = $currentCommit
            CurrentDate = $currentDate
            Available = $availableVersion ? $availableVersion : $currentVersion
            AvailableCommit = $availableCommit ? $availableCommit : $currentCommit
            AvailableDate = $availableDate ? $availableDate : $currentDate
        }
    } |
    Sort-Object -Property @(
        @{ Expression = { $channelSorting.IndexOf($_.Channel) } },
        'Environment'
    )
