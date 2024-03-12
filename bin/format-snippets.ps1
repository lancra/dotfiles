[CmdletBinding()]
param (
    [Parameter()]
    [string]$Source = "$env:XDG_CONFIG_HOME/snippets",
    [Parameter()]
    [string]$Target = "$env:APPDATA/Code/User/snippets"
)

function Format-VisualStudioCodeSnippet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Json,
        [Parameter(Mandatory)]
        [string]$Scope,
        [Parameter(Mandatory)]
        [int]$Padding
    )
    process {
        $filePath = "$Target/$Scope.json"
        $oldCount = 0
        $hasChanges = $true
        if (Test-Path -Path $filePath) {
            $oldCount = jq 'length' $filePath
            $hasChanges = $null -ne ($Json | jd -set $filePath)
        }

        $newCount = $Json | jq 'length'

        $spaces = ' '.PadLeft($Padding - $Scope.Length + 1, ' ')
        Write-Output "vscode ${Scope}:$spaces$oldCount -> $newCount ($($hasChanges ? 'changed' : 'identical'))"
        Set-Content -Path $filePath -Value $Json
    }
}

$snippetPropertySelectors = @(
    # Add the filename (without extension) as a prefix unless it's already set.
    'prefix: (.prefix | to_array + [input_filename | match(".*\\\\(?<prefix>.*)\\.snippet\\.json").captures[0].string] | unique)',
    'title',
    'description',
    'scope: .scope | to_array',
    'body: .body | to_array'
)
$snippetFiles = Get-ChildItem -Path $Source -Filter "*.snippet.json" -Recurse

$allSnippetsJson = jq --compact-output "{ $($snippetPropertySelectors -join ',') }" $snippetFiles |
    jq --slurp

$scopesJson = $allSnippetsJson | jq --compact-output '[.[].scope[]] | unique'
$maxScopeLength = $scopesJson | jq 'max | length'

$scopesJson |
    ConvertFrom-Json |
    ForEach-Object {
        $scope = $_
        $matchingSnippetsJson = $allSnippetsJson | jq --compact-output "[.[] | select(.scope[] | contains(`"$scope`"))]"

        $vsCodeSnippetsJson = $matchingSnippetsJson | jq 'map({ (.title): del(.title, .scope) }) | add' | Out-String
        Format-VisualStudioCodeSnippet -Json $vsCodeSnippetsJson -Scope $scope -Padding $maxScopeLength
    }
