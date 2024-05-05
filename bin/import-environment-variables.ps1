[CmdletBinding()]
param (
    [Parameter()]
    [string]$Source = "$env:XDG_CONFIG_HOME/env/variables.yaml"
)

function Compare-EnvironmentVariable {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$Source
    )
    process {
        Write-Host 'Comparing configured environment variables with the registry.'

        $targetDirectory = "$env:TEMP/$(New-Guid)"
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

        $targetPath = "$targetDirectory/environment-variables.yaml"
        export-environment-variables.ps1 -Target $targetPath

        # Use UTF-8 so that Tee-Object doesn't garble Unicode symbols.
        $originalEncoding = [System.Console]::OutputEncoding
        [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        dyff --color on between --omit-header --set-exit-code $targetPath $Source |
            Tee-Object -Variable differences |
            Write-Host
        $hasDifferences = $LASTEXITCODE -ne 0

        [System.Console]::OutputEncoding = $originalEncoding
        Remove-Item -Path $targetDirectory -Recurse | Out-Null

        $hasDifferences ? $differences : $null
    }
}

$differences = Compare-EnvironmentVariable -Source $Source
if (-not $differences) {
    Write-Output 'No changes detected.'
    exit 0
}

$continueInput = 'y'
$cancelInput = 'N'
$validInputs = @($continueInput, $cancelInput)

$script:input = ''
do {
    $script:input = Read-Host -Prompt "Continue with import? ($continueInput/$cancelInput)"
} while ($script:input -and -not ($validInputs -like $script:input))

if (-not $script:input.Equals($continueInput, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output 'Canceled import.'
    exit 0
}

$sourceObject = Get-Content -Path $Source | ConvertFrom-Yaml

$windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
$runningAsAdministrator = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Output ''

$differences |
    Where-Object { $_.Length -gt 0 -and $_[0] -ne ' ' } |
    ForEach-Object {
        # Remove virtual terminal sequences from dyff output.
        $plaintextVariable = [System.Management.Automation.Internal.StringDecorated]::new($_).ToString('PlainText')
        $parts = $plaintextVariable.Split('.')

        $variableTarget = $parts[0]
        $variableName = $parts[1]

        $variableValue = $sourceObject.$variableTarget.$variableName
        if ($variableValue -is [System.Collections.Generic.List[object]]) {
            $variableValue = ($variableValue -join ';') + ';'
        }

        $variableValueExpanded = [System.Environment]::ExpandEnvironmentVariables($variableValue)

        $variableTargetEnum = [System.EnvironmentVariableTarget]$variableTarget
        if ($variableTargetEnum -eq [System.EnvironmentVariableTarget]::Machine -and -not $runningAsAdministrator) {
            Write-Error "Failed to import $plaintextVariable. Re-execute as an administrator."
            return
        }

        [System.Environment]::SetEnvironmentVariable($variableName, $variableValueExpanded, $variableTargetEnum) | Out-Null
        Write-Output "Imported $plaintextVariable."
    }

Write-Output ''
Write-Output 'Completed import.'
