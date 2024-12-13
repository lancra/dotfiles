class SnippetCollection {
    [Snippet[]]$Values
    [string[]]$Scopes

    SnippetCollection([Snippet[]]$values, [string[]]$scopes) {
        $this.Values = $values
        $this.Scopes = $scopes
    }

    static [SnippetCollection] FromDirectory([string]$path) {
        $snippets = @()

        $files = Get-ChildItem -Path $path -Recurse -Filter '*.snippet.*'
        foreach ($file in $files) {
            $path = $file.FullName
            $extension = [System.IO.Path]::GetExtension($path).Substring(1)
            if ($extension -eq 'json') {
                $snippets += [Snippet]::FromJson($path)
            } elseif ($extension -eq 'sql') {
                $snippets += & "$env:HOME/.local/bin/snippets/read-sql-snippet.ps1" -Path $path
            }
        }

        $snippetScopes = $snippets |
            Select-Object -ExpandProperty Scope -Unique |
            Sort-Object

        return [SnippetCollection]::new($snippets, $snippetScopes)
    }

    [SnippetScopeCollection] ForScope([string]$scope) {
        $scopeSnippets = $this.Values |
            Where-Object -Property Scope -Contains $scope
        return [SnippetScopeCollection]::new($scope, $scopeSnippets)
    }

    [Snippet] ForPrefix([string]$prefix) {
        $snippet = $this.Values |
            Where-Object -Property Prefix -Contains $prefix |
            Select-Object -First 1
        return $snippet
    }
}

class SnippetScopeCollection {
    [string]$Scope
    [Snippet[]]$Values
    [string]$Json

    SnippetScopeCollection([string]$scope, [Snippet[]]$snippets) {
        $this.Scope = $scope
        $this.Values = $snippets
        $this.Json = $this.ToJson($snippets)
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
    [string]$Path
    [string[]]$Prefix
    [string]$Title
    [string]$Description
    [string[]]$Scope
    [string[]]$Body
    [SnippetPlaceholder[]]$Placeholders

    Snippet(
        [string]$path,
        [string[]]$prefix,
        [string]$title,
        [string]$description,
        [string[]]$scope,
        [string[]]$body,
        [SnippetPlaceholder[]]$placeholders) {
        $this.Path = $path
        $this.Prefix = $prefix
        $this.Title = $title
        $this.Description = $description
        $this.Scope = $scope
        $this.Body = $body
        $this.Placeholders = $placeholders
    }

    static [Snippet] FromJson([string]$path) {
        $fileName = [System.IO.Path]::GetFileName($path)
        $filePrefix = $fileName -replace '.snippet.json', ''

        $rawSnippet = Get-Content -Path $path |
            ConvertFrom-Json

        $prefixes = @($rawSnippet.prefix) + $filePrefix |
            Select-Object -Unique

        $snippetPlaceholders = @()
        $snippetPlaceholderHashtable = $rawSnippet.placeholders |
            ConvertTo-Json |
            ConvertFrom-Json -AsHashtable
        if ($null -ne $snippetPlaceholderHashtable) {
            $snippetPlaceholders = $snippetPlaceholderHashtable.GetEnumerator() |
                ForEach-Object {
                    [SnippetPlaceholder]::FromDictionaryEntry($_)
                }
        }

        $snippet = [Snippet]::new(
            $path,
            $prefixes,
            $rawSnippet.title,
            $rawSnippet.description,
            $rawSnippet.scope,
            $rawSnippet.body,
            $snippetPlaceholders)
        return $snippet
    }
}

class SnippetPlaceholder {
    [string]$Key
    [string]$Variable
    [string]$Tooltip

    SnippetPlaceholder([string]$key, [string]$variable, [string]$tooltip) {
        $this.Key = $key
        $this.Variable = $variable
        $this.Tooltip = $tooltip
    }

    static [SnippetPlaceholder] FromDictionaryEntry([System.Collections.DictionaryEntry]$dictionaryEntry) {
        $placeholder = [SnippetPlaceholder]::new(
            $dictionaryEntry.Key,
            $dictionaryEntry.Value.variable,
            $dictionaryEntry.Value.tooltip)
        return $placeholder
    }
}

class SnippetFormatResult {
    [string]$Scope
    [string]$Editor
    [int]$OldCount
    [int]$NewCount
    [bool]$HasChanges

    [string] GetOutput([int]$scopeWidth, [int]$editorWidth) {
        $countFormat = '{0:D3}'

        $scopeOutput = $this.Scope.PadRight($scopeWidth, ' ')
        $editorOutput = $this.Editor.PadRight($editorWidth, ' ')

        $oldCountOutput = $countFormat -f $this.OldCount
        $newCountOutput = $countFormat -f $this.NewCount

        $hasChangesOutput = $this.HasChanges ? 'true' : 'false'

        return "$scopeOutput$editorOutput$oldCountOutput -> $newCountOutput $hasChangesOutput"
    }
}

class SnippetEditor {
    [string]$Key
    [string]$Name
    [string]$TargetDirectory
    [string[]]$Scopes
    [hashtable]$ScopeOverrides

    static [SnippetEditor[]] FromConfiguration() {
        $path = "$env:XDG_CONFIG_HOME/snippets/config.json"

        $editorProperties = @(
            @{Name = 'Key'; Expression = {$_.key}},
            @{Name = 'Name'; Expression = {$_.name}},
            @{Name = 'TargetDirectory'; Expression = {$_.targetDirectory}}
            @{Name = 'Scopes'; Expression = {$_.scopes}},
            @{
                Name = 'ScopeOverrides'
                Expression = {
                    $scopeOverrides = @{}
                    $_.scopeOverrides.PSObject.Properties |
                        ForEach-Object {
                            $scopeOverrides[$_.Name] = $_.Value
                        }
                    return $scopeOverrides
                }}
        )

        $editors = [SnippetEditor[]](Get-Content -Path $path |
            ConvertFrom-Json |
            Select-Object -ExpandProperty editors |
            Select-Object -Property $editorProperties)
        return $editors
    }
}
