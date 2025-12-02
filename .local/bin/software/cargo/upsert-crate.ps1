[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Id
)

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"
$definition = & "$env:BIN/software/get-installation-definitions.ps1" -Export $exportId -Id $Id

$arguments = @()

if ($definition.Examples) {
    $definition.Examples |
        ForEach-Object {
            $arguments += "--example $_"
        }
}

$uri = [uri]::new($Id)
if (-not $Id.EndsWith('.git')) {
    $crateId = $uri.Segments[-1]
    $arguments += $crateId
} else {
    $arguments += "--git $Id"

    $tag = & "$env:BIN/git/get-latest-remote-tag.ps1" -Repository $uri
    $arguments += "--tag $tag"
}

$command = [scriptblock]::Create("cargo install $arguments")
Invoke-Command -ScriptBlock $command
