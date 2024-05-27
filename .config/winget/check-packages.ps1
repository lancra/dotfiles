[CmdletBinding()]
param()

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
        } elseif ($foundHeader -and (-not $foundSeparator)) {
            $foundSeparator = $true
        } elseif ($foundHeader -and (-not $foundFooter)) {
            if ($_.Contains('upgrades available.')) {
                $foundFooter = $true
            } else {
                [ordered]@{
                    provider = 'winget'
                    id = $idDescriptor.GetFrom($_)
                    current = $currentDescriptor.GetFrom($_)
                    available = $availableDescriptor.GetFrom($_)
                }
            }
        }
    } |
    ConvertTo-Json -AsArray
