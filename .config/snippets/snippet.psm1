class Snippet {
    [string[]]$Prefix
    [string]$Title
    [string]$Description
    [string[]]$Scope
    [string[]]$Body
    [SnippetPlaceholder[]]$Placeholders

    static [Snippet[]] FromJsonArray([string]$json) {
        $convertPlaceholdersToArrayQuery = 'map(if .placeholders != null ' +
            'then . + { "placeholders": (.placeholders | to_entries | map(. + .value | del(.value))) } ' +
            'else . end) | ' +
            'map(. + { placeholders: .placeholders | to_array })'
        return [Snippet[]]($json |
            jq --compact-output $convertPlaceholdersToArrayQuery |
            ConvertFrom-Json)
    }

    static [string] ToTextMateJson([Snippet[]]$snippets) {
        $properties = @(
            @{Name = 'prefix'; Expression = {$_.Prefix}},
            @{Name = 'description'; Expression = {$_.Description}},
            @{Name = 'body'; Expression = {$_.Body}}
        )
        $snippetsLookup = [ordered]@{}
        $snippets |
            ForEach-Object {
                $snippetsLookup[$_.Title] = ($_ |
                    Select-Object -Property $properties)
            }

        return $snippetsLookup | ConvertTo-Json
    }
}

class SnippetPlaceholder {
    [string]$Key
    [string]$Variable
    [string]$Tooltip
}
