class SnippetCollection {
    [string]$Scope
    [Snippet[]]$Values
    [string]$Json

    SnippetCollection([string]$scope, [string]$json) {
        $this.Scope = $scope
        $this.Values = $this.FromJsonArray($json)
        $this.Json = $this.ToJson($this.Values)
    }

    hidden [Snippet[]] FromJsonArray([string]$json) {
        $convertPlaceholdersToArrayQuery = 'map(if .placeholders != null ' +
            'then . + { "placeholders": (.placeholders | to_entries | map(. + .value | del(.value))) } ' +
            'else . end) | ' +
            'map(. + { placeholders: .placeholders | to_array })'
        return [Snippet[]]($json |
            jq --compact-output $convertPlaceholdersToArrayQuery |
            ConvertFrom-Json)
    }

    hidden [string] ToJson([Snippet[]]$snippets) {
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

class SnippetFormatResult {
    [string]$Scope
    [string]$Editor
    [int]$OldCount
    [int]$NewCount
    [bool]$HasChanges
}

class SnippetEditor {
    [string]$Key
    [string]$Name
    [string]$TargetDirectory
    [string[]]$Scopes
    [hashtable]$ScopeOverrides
}
