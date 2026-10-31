[CmdletBinding()]
param(
    [Parameter()]
    [string] $Directory,

    [Parameter()]
    [string] $ProfileName,

    [Parameter()]
    [string] $Title,

    [Parameter()]
    [System.Drawing.Color] $Color,

    [switch] $Window
)

$arguments = @(
    'wt',
    "--window '$($Window ? '-1' : '0')'",
    'new-tab'
)

if ($Directory) {
    $arguments += ,"--startingDirectory '$Directory'"
}

if ($ProfileName) {
    $arguments += ,"--profile '$ProfileName'"
}

if ($Title) {
    $arguments += ,"--title '$Title'"
}

if ($Color) {
    $colorHex = "#$($Color.R.ToString('X2'))$($Color.G.ToString('X2'))$($Color.B.ToString('X2'))"
    $arguments += ,"--tabColor '$colorHex'"
}

$command = [scriptblock]::Create($arguments)
Invoke-Command -ScriptBlock $command
