<#
.SYNOPSIS
Finds GitHub Actions references within a filesystem path.

.DESCRIPTION
Searches YAML files within the provided path for action references specified in
uses properties. For references with a pinned ref, the remote tag is identified
if found. Additionally, the latest remote tag is found for the associated
repository.

.PARAMETER Path
The filesystem path to search in. The current working directory is used when
this parameter is not specified.

.PARAMETER Aggregate
Specifies that references should be aggregated by the action and ref pin.

.PARAMETER Check
Specifies that a check against the GitHub repository should be performed to
retrieve ref and tag information.

.PARAMETER Outdated
Specifies that only action references with outdated pins should be returned.
This implicitly excludes pins using branch refs.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Path = $PWD,

    [switch] $Aggregate,
    [switch] $Check,
    [switch] $Outdated
)

enum ActionReferenceType {
    Image
    Local
    Remote
}

class ActionReferenceLocation {
    [string] $Path
    [int] $LineNumber

    ActionReferenceLocation([string] $path, [int] $lineNumber) {
        $this.Path = $path
        $this.LineNumber = $lineNumber
    }

    [string] ToString() {
        return "$($this.Path):$($this.LineNumber)"
    }
}

class ActionReference {
    [ActionReferenceLocation] $Location
    [ActionReferenceType] $Type
    [string] $Path
    [string] $RefName
    [string] $Comment

    ActionReference(
        [ActionReferenceLocation] $location,
        [ActionReferenceType] $type,
        [string] $path,
        [string] $refName,
        [string] $comment
    ) {
        $this.Location = $location
        $this.Type = $type
        $this.Path = $path
        $this.RefName = $refName
        $this.Comment = $comment
    }
}

$actionReferencePrefix = 'uses: '
$actionReferenceMatch = '[-]? uses: '

$actionReferenceProperties = @(
    @{
        Name = 'Content'
        Expression = {
            $_ |
                Select-Object -ExpandProperty 'lines' |
                Select-Object -ExpandProperty 'text' |
                ForEach-Object { $_.Trim() }
        }
    },
    @{
        Name = 'Location'
        Expression = {
            $actionPath = $_ |
                Select-Object -ExpandProperty 'path' |
                Select-Object -ExpandProperty 'text'
            $actionPath = $actionPath -replace '\\', '/'

            $lineNumber = $_ |
                Select-Object -ExpandProperty 'line_number'

            [ActionReferenceLocation]::new($actionPath, $lineNumber)
        }
    }
)

$pathGroupName = 'path'
$refNameGroupName = 'refName'
$commentGroupName = 'comment'
$actionReferencePattern = "(?<$pathGroupName>[^\s]*?)(?:@(?<$refNameGroupName>[^\s]+))?(?:\s*#\s*(?<$commentGroupName>.*))?$"

$actionReferences = & rg --glob "*.yml" --glob "*.yaml" --json "$actionReferenceMatch" $Path |
    ForEach-Object {
        $actionReferenceMatchResult = $_ |
            ConvertFrom-Json
        $actionReferenceMatchType = $actionReferenceMatchResult |
            Select-Object -ExpandProperty 'type'
        if ($actionReferenceMatchType -ne 'match') {
            return
        }

        $actionReferenceMatchResult |
            Select-Object -ExpandProperty 'data' |
            Select-Object -Property $actionReferenceProperties |
            ForEach-Object {
                $actionReferencePrefixIndex = $_.Content.IndexOf($actionReferencePrefix)
                $referenceText = $_.Content.Substring($actionReferencePrefixIndex + $actionReferencePrefix.Length)
                Write-Debug "Parsing '$referenceText' in '$($_.Location.Path):$($_.Location.LineNumber)'."

                $actionReferencePatternMatchGroups = $referenceText |
                    Select-String -Pattern $actionReferencePattern |
                    Select-Object -ExpandProperty Matches |
                    Select-Object -ExpandProperty Groups
                $path = $actionReferencePatternMatchGroups |
                    Where-Object -Property Name -EQ $pathGroupName |
                    Select-Object -ExpandProperty Value
                $refName = $actionReferencePatternMatchGroups |
                    Where-Object -Property Name -EQ $refNameGroupName |
                    Select-Object -ExpandProperty Value
                $comment = ($actionReferencePatternMatchGroups |
                    Where-Object -Property Name -EQ $commentGroupName |
                    Select-Object -ExpandProperty Value) ?? ''

                if ($path.StartsWith('.') -or $path.StartsWith('$/')) {
                    $type = [ActionReferenceType]::Local
                } elseif ($path.StartsWith('docker://')) {
                    $type = [ActionReferenceType]::Image
                } else {
                    $type = [ActionReferenceType]::Remote
                }

                [ActionReference]::new($_.Location, $type, $path, $refName, $comment)
            }
    }

enum RefType {
    Branch
    Commit
    Tag
}

class RemoteRef {
    [RefType] $Type
    [string] $Name
    [string] $RefId
    [string] $TargetId

    RemoteRef([RefType] $type, [string] $name, [string] $refId, [string] $targetId) {
        $this.Type = $type
        $this.Name = $name
        $this.RefId = $refId
        $this.TargetId = $targetId
    }
}

$remoteRefs = @{}
function Get-RemoteRef {
    [CmdletBinding()]
    [OutputType([RemoteRef[]])]
    param(
        [Parameter(Mandatory)]
        [uri] $Repository,

        [Parameter()]
        [string] $Name,

        [Parameter()]
        [string] $Commit
    )
    process {
        $repositoryRefs = $remoteRefs[$Repository]

        if ($null -eq $repositoryRefs) {
            $arguments = @(
                'git ls-remote',
                '--branches',
                '--tags',
                $Repository
            )

            $command = [scriptblock]::Create($arguments)
            $repositoryRefs = Invoke-Command -ScriptBlock $command |
                ForEach-Object {
                    $refSegments = $_ -split "`t"

                    $refPathSegments = $refSegments[1] -split '/'
                    $refType = $refPathSegments[1] -eq 'heads' ? [RefType]::Branch : [RefType]::Tag
                    $refName = $refPathSegments[2..($refPathSegments.Length)] -join '/'

                    $isPointee = $false
                    $pointeeSuffix = '^{}'
                    if ($refName.EndsWith($pointeeSuffix)) {
                        $refName = $refName.Substring(0, $refName.Length - $pointeeSuffix.Length)
                        $isPointee = $true
                    }

                    [pscustomobject]@{
                        Type = $refType
                        Name = $refName
                        Id = $refSegments[0]
                        IsPointee = $isPointee
                    }
                } |
                Group-Object -Property Name |
                ForEach-Object {
                    if (@($_.Group).Length -eq 1) {
                        $refId = $_.Group[0].Id
                        $targetId = $refId
                    } else {
                        $refId = $_.Group |
                            Where-Object -Property IsPointee -EQ $false |
                            Select-Object -ExpandProperty Id -First 1
                        $targetId = $_.Group |
                            Where-Object -Property IsPointee -EQ $true |
                            Select-Object -ExpandProperty Id -First 1
                    }

                    [RemoteRef]::new($_.Group[0].Type, $_.Name, $refId, $targetId)
                }

            $remoteRefs[$Repository] = $repositoryRefs
        }

        $repositoryRefs |
            Where-Object { [string]::IsNullOrEmpty($Name) -or $_.Name -eq $Name } |
            Where-Object { [string]::IsNullOrEmpty($Commit) -or $_.TargetId -eq $Commit }
    }
}

class TagVersion : System.IComparable {
    [string] $Value
    [int[]] $Release
    [string[]] $Prerelease

    TagVersion([string] $value) {
        $this.Value = $value
        $this.Prerelease = @()

        $releaseText = $this.Value.Substring(1)
        $separatorIndex = $this.Value.IndexOf('-')
        if ($separatorIndex -ne -1) {
            $releaseText = $this.Value.Substring(1, $separatorIndex - 1)

            $prereleaseText = $this.Value.Substring($separatorIndex + 1)
            if (-not [string]::IsNullOrEmpty($prereleaseText)) {
                $this.Prerelease = @($prereleaseText.Split('.'))
            }
        }

        $this.Release = @($releaseText.Split('.') |
            ForEach-Object { [int]::Parse($_) })
    }

    [int] CompareTo($other) {
        if (-not ($other -is [TagVersion])) {
            throw "Unable to compare TagVersion to $($other.GetType())."
        }

        $maxReleaseSegments = [int]::Max($this.Release.Length, $other.Release.Length)
        for ($i = 0; $i -lt $maxReleaseSegments; $i++) {
            if ($i -gt ($this.Release.Length - 1)) {
                return -1
            }

            if ($i -gt ($other.Release.Length - 1)) {
                return 1
            }

            $thisSegment = $this.Release[$i]
            $otherSegment = $other.Release[$i]
            $comparison = $thisSegment.CompareTo($otherSegment)
            if ($comparison -ne 0) {
                return $comparison
            }
        }

        $maxPrereleaseSegments = [int]::Max($this.Prerelease.Length, $other.Prerelease.Length)
        for ($i = 0; $i -lt $maxPrereleaseSegments; $i++) {
            if ($i -gt ($this.Prerelease.Length - 1)) {
                return 1
            }

            if ($i -gt ($other.Prerelease.Length - 1)) {
                return -1
            }

            $thisSegment = $this.Prerelease[$i]
            $otherSegment = $other.Prerelease[$i]

            $thisSegmentNumber = $null
            $otherSegmentNumber = $null
            if ([int]::TryParse($thisSegment, [ref] $thisSegmentNumber) -and
                [int]::TryParse($otherSegment, [ref] $otherSegmentNumber)) {
                $comparison = $thisSegmentNumber.CompareTo($otherSegmentNumber)
            } else {
                $comparison = $thisSegment.CompareTo($otherSegment)
            }

            if ($comparison -ne 0) {
                return $comparison
            }
        }

        return 0
    }

    [string] ToString() {
        return $this.Value
    }
}

class RemoteTag {
    [TagVersion] $Version
    [string] $RefId
    [string] $TargetId

    RemoteTag([TagVersion] $version, [string] $refId, [string] $targetId) {
        $this.Version = $version
        $this.RefId = $refId
        $this.TargetId = $targetId
    }

    [string] ToString() {
        return "$($this.Version) ($($this.TargetId))"
    }
}

$latestRemoteTags = @{}
function Get-LatestRemoteTagVersion {
    [CmdletBinding()]
    [OutputType([RemoteTag])]
    param(
        [Parameter(Mandatory)]
        [uri] $Repository
    )
    process {
        $latestRemoteTag = $latestRemoteTags[$Repository]
        if ($null -eq $latestVersionSnapshot) {
            $latestRemoteTag = Get-RemoteRef -Repository $repositoryUri |
                Where-Object -Property Type -EQ ([RefType]::Tag) |
                Where-Object { $_.Name.StartsWith('v') } |
                ForEach-Object {
                    $version = [TagVersion]::new($_.Name)
                    [RemoteTag]::new($version, $_.RefId, $_.TargetId)
                } |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
            $latestRemoteTags[$Repository] = $latestRemoteTag
        }

        $latestRemoteTag
    }
}

class RemoteActionReferenceMetadata {
    [RefType] $RefType
    [RemoteTag] $CurrentTag
    [RemoteTag] $LatestTag

    RemoteActionReferenceMetadata([RefType] $refType, [RemoteTag] $currentTag, [RemoteTag] $latestTag) {
        $this.RefType = $refType
        $this.CurrentTag = $currentTag
        $this.LatestTag = $latestTag
    }
}

class RemoteActionReference {
    [string] $Repository
    [string] $ActionPath
    [string] $RefName
    [string] $Comment
    [ActionReferenceLocation] $Location
    [RemoteActionReferenceMetadata] $Metadata

    static [hashtable[]] $MemberDefinitions = @(
        @{
            MemberType = 'ScriptProperty'
            MemberName = 'Path'
            Value = { $this.get_Path() }
        }
    )

    static RemoteActionReference() {
        $typeName = [RemoteActionReference].Name
        foreach ($definition in [RemoteActionReference]::MemberDefinitions) {
            Update-TypeData -TypeName $typeName -Force @definition
        }

        $defaultDisplayProperties = @(
            'Path',
            'RefName',
            'Comment',
            'Location'
        )
        Update-TypeData -TypeName $typeName -Force -DefaultDisplayPropertySet $defaultDisplayProperties
    }

    RemoteActionReference(
        [string] $repository,
        [string] $actionPath,
        [string] $refName,
        [string] $comment,
        [ActionReferenceLocation] $location,
        [RemoteActionReferenceMetadata] $metadata
    ) {
        $this.Repository = $repository
        $this.ActionPath = $actionPath
        $this.RefName = $refName
        $this.Comment = $comment
        $this.Location = $location
        $this.Metadata = $metadata
    }

    hidden [string] get_Path() {
        $path = $this.Repository
        if ($this.ActionPath) {
            $path += "/$($this.ActionPath)"
        }

        return $path
    }
}

class RemoteActionReferenceAggregate {
    [string] $Repository
    [string] $ActionPath
    [string] $RefName
    [ActionReferenceLocation[]] $Locations
    [RemoteActionReferenceMetadata] $Metadata

    static [hashtable[]] $MemberDefinitions = @(
        @{
            MemberType = 'ScriptProperty'
            MemberName = 'Count'
            Value = { $this.Locations.Length }
        },
        @{
            MemberType = 'ScriptProperty'
            MemberName = 'Path'
            Value = { $this.get_Path() }
        }
    )

    static RemoteActionReferenceAggregate() {
        $typeName = [RemoteActionReferenceAggregate].Name
        foreach ($definition in [RemoteActionReferenceAggregate]::MemberDefinitions) {
            Update-TypeData -TypeName $typeName -Force @definition
        }

        $defaultDisplayProperties = @(
            'Path',
            'RefName',
            'Count'
        )
        Update-TypeData -TypeName $typeName -Force -DefaultDisplayPropertySet $defaultDisplayProperties
    }

    RemoteActionReferenceAggregate(
        [string] $repository,
        [string] $actionPath,
        [string] $refName,
        [ActionReferenceLocation[]] $locations,
        [RemoteActionReferenceMetadata] $metadata
    ) {
        $this.Repository = $repository
        $this.ActionPath = $actionPath
        $this.RefName = $refName
        $this.Locations = $locations
        $this.Metadata = $metadata
    }

    hidden [string] get_Path() {
        $path = $this.Repository
        if ($this.ActionPath) {
            $path += "/$($this.ActionPath)"
        }

        return $path
    }
}

$groupingProperty = $Aggregate ? @{ Expression = { "$($_.Path)@$($_.RefName)" } } : 'Location'
$actionReferences |
    Where-Object -Property Type -EQ ([ActionReferenceType]::Remote) |
    Group-Object -Property $groupingProperty |
    ForEach-Object {
        $locations = $_ |
            Select-Object -ExpandProperty Group |
            Select-Object -ExpandProperty Location
        $locationDescription = @($locations).Length -eq 1 ? "'$locations'" : "$($locations.Length) locations"
        Write-Verbose "Retrieving remote metadata for '$($_.Name)' in $locationDescription."

        $actionReference = @($_.Group)[0]

        $pathSegments = $actionReference.Path -split '/'
        $repository = $pathSegments[0..1] -join '/'
        $actionPath = $pathSegments[2..($pathSegments.Length)] -join '/'

        $metadata = $null
        if ($Check -or $Outdated) {
            $repositoryUri = [uri]::new("https://github.com/$Repository.git")
            $remoteRef = Get-RemoteRef -Repository $repositoryUri -Name $actionReference.RefName
            $refType = $remoteRef.Type ?? [RefType]::Commit

            $refCommit = $remoteRef.TargetId ?? $actionReference.RefName
            $currentTag = $remoteRef ?? (Get-RemoteRef -Repository $repositoryUri -Commit $refCommit) |
                Where-Object -Property Type -EQ ([RefType]::Tag) |
                Where-Object { $_.Name.StartsWith('v') } |
                ForEach-Object {
                    $version = [TagVersion]::new($_.Name)
                    [RemoteTag]::new($version, $_.RefId, $_.TargetId)
                } |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
            $latestTag = Get-LatestRemoteTagVersion -Repository $repositoryUri

            $metadata = [RemoteActionReferenceMetadata]::new($refType, $currentTag, $latestTag)
        }

        $Aggregate `
            ? [RemoteActionReferenceAggregate]::new(
                $repository,
                $actionPath,
                $actionReference.RefName,
                $locations,
                $metadata
            ) `
            : [RemoteActionReference]::new(
                $repository,
                $actionPath,
                $actionReference.RefName,
                $actionReference.Comment,
                $locations[0],
                $metadata
            )
    } |
    Where-Object {
        -not $Outdated -or
        ($_.Metadata.CurrentTag.TargetId -and $_.Metadata.CurrentTag.TargetId -ne $_.Metadata.LatestTag.TargetId)
    }
