using module ../.local/bin/snippets/snippets.psm1

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$Source = "$env:XDG_CONFIG_HOME/snippets",
    [switch]$SkipVisualStudio
)

$scopeResultWidth = 15
$editorResultWidth = 10

function Write-SnippetFormatResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [SnippetFormatResult]$Result
    )
    begin {
        $countFormat = '{0:D3}'
    }
    process {
        $scope = $Result.Scope.PadRight($scopeResultWidth, ' ')
        $editor = $Result.Editor.PadRight($editorResultWidth, ' ')

        $oldCount = $countFormat -f $Result.OldCount
        $newCount = $countFormat -f $Result.NewCount

        $hasChanges = $Result.HasChanges ? 'true' : 'false'

        Write-Output "$scope$editor$oldCount -> $newCount $hasChanges"
    }
}

$snippets = [SnippetCollection]::FromDirectory($Source)
$editors = [SnippetEditor]::FromConfiguration()

$header = "$('Scope'.PadRight($scopeResultWidth))$('Editor'.PadRight($editorResultWidth))Old    New Changes"
Write-Output $header
Write-Output ([string]::new('-', $header.Length))

$snippets.Scopes |
    ForEach-Object {
        $scope = $_
        $scopeSnippets = $snippets.ForScope($scope)
        foreach ($editor in $editors) {
            if ($editor.Key -eq 'vs' -and $SkipVisualStudio) {
                continue
            }

            if ($null -ne $editor.Scopes -and -not ($editor.Scopes -contains $scope)) {
                continue
            }

            $scriptPath = "$env:HOME/.local/bin/snippets/$($editor.Key)/format-snippets.ps1"
            $formatResult = [SnippetFormatResult](& $scriptPath -Snippets $scopeSnippets -Configuration $editor)
            $formatResult.GetOutput($scopeResultWidth, $editorResultWidth) | Write-Output
        }
    }
