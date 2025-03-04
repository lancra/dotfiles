[CmdletBinding()]
param()

$idGroup = 'id'
$versionGroup = 'version'
$toolchainRegex = "(?<$idGroup>.*?) - (?<status>.*?) : (?<$versionGroup>.*)"

$channelGroup = 'channel'
$environmentGroup = 'environment'
$idRegex = "(?<$channelGroup>.*?)-(?<host>(?<architecture>.*?)-(?<operating_system>.*)-(?<$environmentGroup>.*))"

$currentVersionGroup = 'current_version'
$currentDateGroup = 'current_date'
$availableVersionGroup = 'available_version'
$availableDateGroup = 'available_date'

$currentRegex = "(?<$currentVersionGroup>.*?) \((?<current_commit>.*?) (?<$currentDateGroup>.*?)\)"
$availableRegex = "(?<$availableVersionGroup>.*?) \((?<available_commit>.*?) (?<$availableDateGroup>.*?)\)"
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
        $currentDate = Get-GroupValue -Match $versionMatch -Group $currentDateGroup
        $currentDate = [DateOnly]::Parse($currentDate)
        $current = $currentVersion
        if ($current.Contains('-')) {
            $current = "$current.$($currentDate.ToString('yyyyMMdd'))"
        }

        $availableVersion = Get-GroupValue -Match $versionMatch -Group $availableVersionGroup
        $availableDate = Get-GroupValue -Match $versionMatch -Group $availableDateGroup
        $available = $availableVersion ? $availableVersion : $currentVersion
        if ($available.Contains('-')) {
            $availableDate = $availableDate ? [DateOnly]::Parse($availableDate) : $currentDate
            $available = "$available.$($availableDate.ToString('yyyyMMdd'))"
        }

        @{
            Id = $id
            Name = "$channel ($environment)"
            Channel = $channel
            Environment = $environment
            Current = $current
            Available = $available
        }
    } |
    Sort-Object -Property @(
        @{ Expression = { $channelSorting.IndexOf($_.Channel) } },
        'Environment'
    )
