using module ./snippets/snippets.psm1

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string] $Source = "$env:XDG_CONFIG_HOME/snippets",
    [Parameter()]
    [string[]] $Scope,
    [switch] $SkipVisualStudio
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
        $scopeName = $Result.Scope.PadRight($scopeResultWidth, ' ')
        $editor = $Result.Editor.PadRight($editorResultWidth, ' ')

        $oldCount = $countFormat -f $Result.OldCount
        $newCount = $countFormat -f $Result.NewCount

        $hasChanges = $Result.HasChanges ? 'true' : 'false'

        Write-Output "$scopeName$editor$oldCount -> $newCount $hasChanges"
    }
}

$snippets = [SnippetCollection]::FromDirectory($Source)
$editors = [SnippetEditor]::FromConfiguration()

$header = "$('Scope'.PadRight($scopeResultWidth))$('Editor'.PadRight($editorResultWidth))Old    New Changes"
Write-Output $header
Write-Output ([string]::new('-', $header.Length))

$snippets.Scopes |
    Where-Object { $Scope.Length -eq 0 -or $Scope -contains $_ } |
    ForEach-Object {
        $scopeName = $_
        $scopeSnippets = $snippets.ForScope($scopeName)
        foreach ($editor in $editors) {
            if ($editor.Key -eq 'vs' -and $SkipVisualStudio) {
                continue
            }

            if ($null -ne $editor.Scopes -and -not ($editor.Scopes -contains $scopeName)) {
                continue
            }

            $scriptPath = "$env:HOME/.local/bin/snippets/$($editor.Key)/format-snippets.ps1"
            $formatResult = [SnippetFormatResult](& $scriptPath -Snippets $scopeSnippets -Configuration $editor)
            $formatResult.GetOutput($scopeResultWidth, $editorResultWidth) | Write-Output
        }
    }
