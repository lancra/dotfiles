[CmdletBinding()]
param(
    [Parameter()]
    $SourceDirectory = "$env:USERPROFILE/.config/lancra/azuredatastudio/snippets",

    [Parameter()]
    $TargetFile = "$env:USERPROFILE/AppData/Roaming/azuredatastudio/User/snippets/sql.json"
)

enum LineKind {
    # Represents a scan for another section of the snippet.
    Scan

    # Represents metadata which describes the snippet.
    Metadata

    # Represents parameters which a user can provide inputs to.
    Parameters

    # Represents the snippet content.
    Content
}

class Snippet {
    [string]$Title
    [string]$Prefix
    [string]$Description
    [string[]]$Body

    Snippet([string]$fileName, [hashtable]$metadata, [string[]]$lines) {
        $this.Prefix = $metadata['PREFIX'] ?? $fileName
        $this.Title = $metadata['TITLE'] ?? $this.Prefix
        $this.Description = $metadata['DESCRIPTION']
        $this.Body = $lines
    }
}

function Import-TextSnippet {
    [CmdletBinding()]
    [OutputType([Snippet[]])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceDirectory
    )
    begin {
        $metadataBegin = 'METADATA_BEGIN'
        $metadataEnd = 'METADATA_END'
        $lineKindActions = @{
            $metadataBegin = [System.Func[bool, LineKind]]{ param($hasParams) [LineKind]::Metadata }
            $metadataEnd = [System.Func[bool, LineKind]]{ param($hasParams) [LineKind]::Content }
        }
    }
    process {
        $snippets = @()
        $files = @(Get-ChildItem -Path $SourceDirectory -Recurse | Where-Object { $_.Extension -eq '.txt' })
        foreach ($file in $files) {
            $metadata = @{}
            $lines = @()

            $fileLines = Get-Content -Path $file.FullName
            $currentKind = [LineKind]::Scan
            $earlyExit = $false

            foreach ($line in $fileLines) {
                $action = $lineKindActions[$line]
                if ($null -ne $action) {
                    $currentKind = $action.Invoke($false)
                    continue
                }

                if ($currentKind -eq [LineKind]::Metadata) {
                    $equalsIndex = $line.IndexOf('=')
                    if ($equalsIndex -eq -1) {
                        Write-Error -Message "Metadata line is not written in the 'KEY=VALUE' format for '$($file.FullName)'."
                        $earlyExit = $true
                        break
                    }

                    $metadataKey = $line.Substring(0, $equalsIndex)
                    $metadataValue = $line.Substring($equalsIndex + 1)
                    $metadata[$metadataKey] = $metadataValue
                } elseif ($currentKind -eq [LineKind]::Content) {
                    $lines += $line
                }
            }

            if ($earlyExit) {
                continue
            }

            $snippets += [Snippet]::new($file.BaseName, $metadata, $lines)
        }

        return $snippets
    }
}

function Format-SqlServerParameter {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Line,

        [Parameter(Mandatory)]
        [int]$Number
    )
    begin {
        $quotedTypes = @(
            'char',
            'date'
            'datetime'
            'datetime2'
            'datetimeoffset'
            'hierarchyid'
            'nchar'
            'ntext'
            'nvarchar'
            'smalldatetime'
            'sysname'
            'text'
            'time'
            'uniqueidentifier'
            'varchar'
            'xml'
        )
        $quotedTypeLookup = @{}
        $quotedTypes | ForEach-Object { $quotedTypeLookup[$_] = $_ }
    }
    process {
        # DECLARE @<VARIABLE> <DATA_TYPE> [= <VALUE>]
        #        |           |             |
        #        FirstSpace  SecondSpace   Equals

        $firstSpaceIndex = $Line.IndexOf(' ')
        $secondSpaceIndex = $Line.IndexOf(' ', $firstSpaceIndex + 1)
        $equalsIndex = $Line.IndexOf('=', $secondSpaceIndex + 1)

        $name = $Line.Substring($firstSpaceIndex + 2, $secondSpaceIndex - $firstSpaceIndex - 2)
        $typeRaw = $Line.Substring(
            $secondSpaceIndex + 1,
            ($equalsIndex -ne -1 ? $equalsIndex - 1 : $Line.Length) - $secondSpaceIndex - 1);

        $typeParenthsesIndex = $typeRaw.IndexOf('(')
        $type = $typeParenthsesIndex -eq -1 ? $typeRaw : $typeRaw.Substring(0, $typeParenthsesIndex)
        $typeIsQuoted = $quotedTypeLookup.ContainsKey($type)

        $valueRaw = "`${${Number}:$name}"
        $value = $typeIsQuoted ? "'$valueRaw'" : $valueRaw

        $newLine = "DECLARE @$name $typeRaw = $value"
        return $newLine
    }
}

function Import-SqlServerSnippet {
    [CmdletBinding()]
    [OutputType([Snippet[]])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceDirectory
    )
    begin {
        $metadataBegin = '/*METADATA_BEGIN'
        $metadataEnd = 'METADATA_END*/'
        $parametersBegin = '--PARAMETERS_BEGIN'
        $parametersEnd = '--PARAMETERS_END'
        $lineKindActions = @{
            $metadataBegin = [System.Func[bool, LineKind]]{ param($hasParameters) [LineKind]::Metadata }
            $metadataEnd = [System.Func[bool, LineKind]]{
                param($hasParameters) $hasParameters ? [LineKind]::Scan : [LineKind]::Content }
            $parametersBegin = [System.Func[bool, LineKind]]{ param($hasParameters) [LineKind]::Parameters }
            $parametersEnd = [System.Func[bool, LineKind]]{ param($hasParameters) [LineKind]::Content }
        }
    }
    process {
        $snippets = @()
        $files = @(Get-ChildItem -Path $SourceDirectory -Recurse | Where-Object { $_.Extension -eq '.sql' })
        foreach ($file in $files) {
            $metadata = @{}
            $lines = @()

            $fileLines = Get-Content -Path $file.FullName
            $hasParameters = $fileLines.Contains($parametersBegin) -or $lines.Contains($parametersEnd)
            $parameterNumber = 1

            $currentKind = [LineKind]::Scan
            $earlyExit = $false

            foreach ($line in $fileLines) {
                $action = $lineKindActions[$line]
                if ($null -ne $action) {
                    $currentKind = $action.Invoke($hasParameters)
                    continue
                }

                if ($currentKind -eq [LineKind]::Metadata) {
                    $equalsIndex = $line.IndexOf('=')
                    if ($equalsIndex -eq -1) {
                        Write-Error -Message "Metadata line is not written in the 'KEY=VALUE' format for '$($file.FullName)'."
                        $earlyExit = $true
                        break
                    }

                    $metadataKey = $line.Substring(0, $equalsIndex)
                    $metadataValue = $line.Substring($equalsIndex + 1)
                    $metadata[$metadataKey] = $metadataValue
                } elseif ($currentKind -eq [LineKind]::Parameters) {
                    $lines += Format-SqlServerParameter -Line $line -Number $parameterNumber
                    $parameterNumber++
                } elseif ($currentKind -eq [LineKind]::Content) {
                    $lines += $line
                }
            }

            if ($earlyExit) {
                continue
            }

            $snippets += [Snippet]::new($file.BaseName, $metadata, $lines)
        }

        return $snippets
    }
}

$textSnippets = Import-TextSnippet -SourceDirectory $SourceDirectory
$sqlServerSnippets = Import-SqlServerSnippet -SourceDirectory $SourceDirectory
$snippets = $($textSnippets; $sqlServerSnippets)

$exportSnippets = [ordered]@{}
$snippets |
    Sort-Object -Property Title |
    ForEach-Object {
        $exportSnippet = [PSCustomObject]@{
            prefix = $_.Prefix
            description = $_.Description
            body = $_.Body
        }

        $exportSnippetPopulatedPropertyNames = $exportSnippet.PSObject.Properties.Name |
            Where-Object { $null -ne $exportSnippet.$PSItem } |
            Where-Object { -not [string]::IsNullOrEmpty($exportSnippet.$PSItem) }
        $exportSnippets[$_.Title] = $exportSnippet |
            Select-Object -Property $exportSnippetPopulatedPropertyNames
    }

[PSCustomObject]$exportSnippets |
    ConvertTo-Json |
    Out-File -FilePath $TargetFile

Write-Host "Regenerated snippets file from $($textSnippets.Length) text files and $($sqlServerSnippets.Length) SQL files."
