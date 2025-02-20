using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:HOME/.local/bin/software/get-export-id-from-path.ps1"

class ColumnDescriptor {
    [int]$Index
    [int]$Length

    ColumnDescriptor([int]$index, [int]$length) {
        $this.Index = $index
        $this.Length = $length
    }

    [string] GetFrom([string]$line) {
        return $line.Substring($this.Index, $this.Length).TrimEnd()
    }
}

$foundHeader = $false
$foundSeparator = $false

$idDescriptor = $null
$sourceDescriptor = $null

& winget pin list |
    ForEach-Object {
        if ((-not $foundHeader) -and $_.StartsWith('Name ')) {
            $foundHeader = $true

            $idIndex = $_.IndexOf('Id')
            $versionIndex = $_.IndexOf('Version')
            $sourceIndex = $_.IndexOf('Source')
            $pinTypeIndex = $_.IndexOf('Pin type')

            $idDescriptor = [ColumnDescriptor]::new($idIndex, $versionIndex - $idIndex)
            $sourceDescriptor = [ColumnDescriptor]::new($sourceIndex, $pinTypeIndex - $sourceIndex)
        } elseif ($foundHeader -and (-not $foundSeparator)) {
            $foundSeparator = $true
        } elseif ($foundHeader -and $foundSeparator) {
            $id = $idDescriptor.GetFrom($_)
            $source = $sourceDescriptor.GetFrom($_)
            "$id@$source"
        }
    } |
    ForEach-Object {
        $id = [InstallationId]::new($_, $exportId)
        $metadata = [ordered]@{}

        [Installation]::new($id, $metadata)
    }
