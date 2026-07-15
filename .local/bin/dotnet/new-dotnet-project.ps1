<#
.SYNOPSIS
Adds a minimal .NET project to the working directory.

.DESCRIPTION
The project name is first Determined using the solution in the working directory
and the provided Name. Then the project directory and file(s) are written to
disk. If any references are specified, they are added via the .NET CLI command.
Finally, the project is added to the solution using the .NET CLI command.

.PARAMETER Template
The template to use for project creation.

.PARAMETER Name
The name of the project directory and the project file suffix.

.PARAMETER Directory
The directory to create the project directory in. When no value is provided,
this defaults to "src".

.PARAMETER Reference
The projects that the new project should reference.

.PARAMETER Force
Specifies that the operation should continue when the project directory already
exists.

.PARAMETER NoPrefix
Specifies that the solution name should not be added as a prefix to the project
file name.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Template,

    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter()]
    [string] $Directory = 'src',

    [Parameter()]
    [string[]] $Reference = @(),

    [switch] $Force,
    [switch] $NoPrefix
)

$consoleTemplate = 'console'
$libraryTemplate = 'library'
$testTemplate = 'test'
$templateAliases = @{
    classlib = $libraryTemplate
    cli = $consoleTemplate
    $consoleTemplate = $consoleTemplate
    lib = $libraryTemplate
    $libraryTemplate = $libraryTemplate
    $testTemplate = $testTemplate
    tests = $testTemplate
    testing = $testTemplate
    xunit = $testTemplate
}

$targetTemplate = $templateAliases[$Template]
if ($null -eq $targetTemplate) {
    $availableTemplates = ($templateAliases.GetEnumerator() |
        Group-Object -Property Value |
        ForEach-Object {
            $groupTemplate = $_.Name
            $aliases = $_.Group |
                Select-Object -ExpandProperty Key |
                Where-Object { $_ -ne $template } |
                Sort-Object

            "    ${groupTemplate}: $($aliases -join ', ')"
        }) -join [System.Environment]::NewLine

    $message = "The provided template '$Template' is not configured.$([System.Environment]::NewLine)" + `
        "Use one of the following templates or aliases:$([System.Environment]::NewLine)$availableTemplates"
    Write-Output "$($PSStyle.Foreground.Red)$message$($PSStyle.Reset)"
    exit 1
}

$outputPath = "$Directory/$Name"
$outputPathExists = Test-Path -Path $outputPath
if ($outputPathExists -and -not $Force) {
    $message = "The output path '$outputPath' already exists.$([System.Environment]::NewLine)" + `
        "Change Directory and/or Name, or run with the Force parameter."
    Write-Output "$($PSStyle.Foreground.Red)$message$($PSStyle.Reset)"
    exit 1
}

$solutionExtension = '.slnx'
$solutionFile = Get-ChildItem -Filter "*$solutionExtension" |
    Select-Object -First 1
$solutionName = $solutionFile.Name.Substring(0, $solutionFile.Name.Length - $solutionExtension.Length)

$namePrefix = -not $NoPrefix ? "$solutionName." : ''
$projectFileName = "$namePrefix$Name.csproj"

function Get-ExecutableProjectContent {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    process {
        @(
            '<Project Sdk="Microsoft.NET.Sdk">'
            '',
            '  <PropertyGroup>'
            '    <OutputType>Exe</OutputType>'
            '  </PropertyGroup>'
            '',
            '</Project>'
        ) -join [System.Environment]::NewLine
    }
}

Write-Verbose 'Adding project'
New-Item -ItemType Directory -Path $outputPath -Force |
    Out-Null

switch ($targetTemplate) {
    $consoleTemplate {
        Set-Content -Path "$outputPath/$projectFileName" -Value (Get-ExecutableProjectContent) -Force |
            Out-Null

        Set-Content -Path "$outputPath/Program.cs" -Value 'Console.WriteLine();' |
            Out-Null
    }
    $testTemplate {
        Set-Content -Path "$outputPath/$projectFileName" -Value (Get-ExecutableProjectContent) -Force |
            Out-Null

        $sampleTestContent = @(
            "namespace $solutionName.$Name;",
            '',
            'public class SampleTest',
            '{'
            '    [Fact]'
            '    public void Run()'
            '    {'
            '    }'
            '}'
        ) -join [System.Environment]::NewLine
        Set-Content -Path "$outputPath/SampleTest.cs" -Value $sampleTestContent
    }
    $libraryTemplate {
        Set-Content -Path "$outputPath/$projectFileName" -Value '<Project Sdk="Microsoft.NET.Sdk" />' -Force |
            Out-Null
    }
    default { throw "Unrecognized template '$targetTemplate'." }
}

$Reference |
    ForEach-Object {
        Write-Verbose "Adding reference to $_"
        $addProjectReferenceArguments = @(
            'dotnet add',
            "'$outputPath'",
            'reference',
            "'$_'"
        )
        $addProjectReferenceCommand = [scriptblock]::Create($addProjectReferenceArguments)
        Write-Debug $addProjectReferenceCommand.ToString()
        & $addProjectReferenceCommand
    }

Write-Verbose 'Adding project to solution'
$modifySolutionArguments = @(
    'dotnet sln',
    "'$($solutionFile.FullName)'",
    'add',
    "'$outputPath'",
    "--solution-folder '$Directory'"
)
$modifySolutionCommand = [scriptblock]::Create($modifySolutionArguments)
Write-Debug $modifySolutionCommand.ToString()
& $modifySolutionCommand
