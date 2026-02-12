<#
.SYNOPSIS
Prunes notes from a repository where the commit is not found on any branch.

.DESCRIPTION
Retrieves the list of notes for the repository. Then, for each commit, checks
whether any remove or local branch contains the commit. If this check passes,
the note is retained. Otherwise, the note is removed.

.PARAMETER Repository
The repository to operate against. The current directory is used when no value
is provided.

.PARAMETER Check
Displays the operation for each commit, either retaining or removing, instead of
deleting any commits.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string] $Repository = $PWD,

    [switch] $Check
)

$repositoryRoot = & "$env:BIN/git/get-repository-root.ps1" -Path $Repository
git -C $repositoryRoot notes list |
    ForEach-Object {
        $noteIds = $_ -split ' '
        $commitId = $noteIds[1]
        $inBranch = $null -ne (git -C $repositoryRoot branch --all --contains $commitId)

        if ($Check) {
            $prefix = $inBranch ? 'RETAIN' : 'REMOVE'
            $colorCode = $inBranch ? 32 : 31
            Write-Output "`e[${colorCode}m$prefix $commitId`e[39m"
        } elseif (-not $inBranch) {
            git -C $repositoryRoot notes remove $commitId
        } else {
            Write-Output "Retaining note for object $commitId"
        }
    }
