class Snippet {
    [string[]]$Prefix
    [string]$Title
    [string]$Description
    [string[]]$Scope
    [string[]]$Body
    [SnippetPlaceholder[]]$Placeholders
}

class SnippetPlaceholder {
    [string]$Key
    [string]$Variable
    [string]$Tooltip
}
