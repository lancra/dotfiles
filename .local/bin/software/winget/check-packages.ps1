using module ../software.psm1

[CmdletBinding()]
param()

$exportId = & "$env:BIN/software/get-export-id-from-path.ps1"

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
$foundFooter = $false

$idDescriptor = $null
$currentDescriptor = $null
$availableDescriptor = $null
$sourceDescriptor = $null

& winget upgrade |
    ForEach-Object {
        if ((-not $foundHeader) -and $_.StartsWith('Name ')) {
            $foundHeader = $true

            $idIndex = $_.IndexOf('Id')
            $currentIndex = $_.IndexOf('Version')
            $availableIndex = $_.IndexOf('Available')
            $sourceIndex = $_.IndexOf('Source')

            $idDescriptor = [ColumnDescriptor]::new($idIndex, $currentIndex - $idIndex)
            $currentDescriptor = [ColumnDescriptor]::new($currentIndex, $availableIndex - $currentIndex)
            $availableDescriptor = [ColumnDescriptor]::new($availableIndex, $sourceIndex - $availableIndex)
            $sourceDescriptor = [ColumnDescriptor]::new($sourceIndex, $_.Length - $sourceIndex)
        } elseif ($foundHeader -and (-not $foundSeparator)) {
            $foundSeparator = $true
        } elseif ($foundHeader -and (-not $foundFooter)) {
            if ($_.Contains('upgrades available.') -or $_ -match '. package\(s\)') {
                $foundFooter = $true
            } else {
                $packageName = $idDescriptor.GetFrom($_)
                $packageId = "$packageName@$($sourceDescriptor.GetFrom($_))"
                $id = [InstallationId]::new($packageId, $exportId)
                [InstallationUpgrade]::new($id, $packageName, $currentDescriptor.GetFrom($_), $availableDescriptor.GetFrom($_))
            }
        }
    }
