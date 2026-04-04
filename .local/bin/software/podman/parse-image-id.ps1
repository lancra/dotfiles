[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

$repositoryTag = $Id.Split(':')

$parts = $repositoryTag[0].Split('/')

$hasNamespace = $parts.Length -gt 2
$namespace = $hasNamespace ? $parts[1] : ''

$repositoryStartIndex = $hasNamespace ? 2 : 1
$repository = [string]::Join('/', $parts[$repositoryStartIndex..($parts.Length - 1)])
$tag = $repositoryTag.Length -gt 1 ? $repositoryTag[1] : ''

[pscustomobject]@{
    Id = $Id
    Registry = $parts[0]
    Namespace = $namespace
    Repository = $repository
    Tag = $tag
}
