<#
.SYNOPSIS
Transforms snippet definitions into formats usable by various editors.

.DESCRIPTION
Recursively finds all snippet definitions files in the source directory. Then,
an editor-specific transformation is applied to each snippet to ensure it can be
consumed. Depending on the editor, the snippets are then written as individual
files or combined into an aggregate file.

.PARAMETER Source
The path of the source directory for snippet definitions.

.PARAMETER Scope
The scopes to include for formatting. If no scopes are specified, all scopes are
included.

.PARAMETER SkipVisualStudio
Specifies that snippet formatting should be skipped for the Visual Studio
editor. Attempting to change snippets for this editor while it is running
results in locks on the files between the script and Visual Studio. This
parameter is useful when attempting to format snippets for another editor.

.INPUTS
The source directory can be piped in.

.OUTPUTS
Outputs a table containing the overview of changes by scope and editor.
#>

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

            if ($null -ne $editor.Scopes -and $editor.IgnoreUndefinedScopes) {
                $editorScopeKeys = $editor.Scopes |
                    Select-Object -ExpandProperty Key
                if (-not ($editorScopeKeys -contains $scopeName)) {
                    continue
                }
            }

            $scriptPath = "$env:BIN/snippets/$($editor.Key)/format-snippets.ps1"
            $formatResult = [SnippetFormatResult](& $scriptPath -Snippets $scopeSnippets -Configuration $editor)
            $formatResult.GetOutput($scopeResultWidth, $editorResultWidth) | Write-Output
        }
    }
