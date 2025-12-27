[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Path')]
    [string] $Path,

    [Parameter(ParameterSetName = 'Content')]
    [string[]] $Content
)

if ($PSCmdlet.ParameterSetName -eq 'Path') {
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Cannot find path '$Path' because it does not exist."
        exit 1
    }

    $Content = Get-Content -Path $Path
}

function Expand-Value {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string] $Value,

        [Parameter()]
        [string] $QuoteCharacter
    )
    process {
        if ($QuoteCharacter -ne '"') {
            return $Value
        }

        $newValue = $Value
        $newValue = $newValue.Replace('\n', "`n")
        $newValue = $newValue.Replace('\t', "`t")
        return $newValue
    }
}

$keyValues = @{}
$lines = @($Content)
for ($lineIndex = 0; $lineIndex -lt $lines.Length; $lineIndex++) {
    $line = $lines[$lineIndex]

    $firstLineCharacter = $line |
        Select-String -Pattern '[^\s]' |
        Select-Object -ExpandProperty Matches |
        Select-Object -ExpandProperty Value
    if (@($null, '#') -contains $firstLineCharacter) {
        continue
    }

    $equalsIndex = $line.IndexOf('=')
    if ($equalsIndex -eq -1) {
        Write-Error "No key-value separator found on line $($lineIndex + 1) '$line'."
        continue
    }

    $key = $line.Substring(0, $equalsIndex).Trim()

    $value = $line.Substring($equalsIndex + 1).TrimStart()
    $firstValueCharacter = $value.Length -gt 0 ? $value[0] : $null
    $isQuoted = @("'", '"', '`') -contains $firstValueCharacter
    $quoteMatches = $null -ne $firstValueCharacter `
        ? @($value |
            Select-String -Pattern $firstValueCharacter -AllMatches |
            Select-Object -ExpandProperty Matches) `
        : @()

    if (-not $isQuoted) {
        $endIndex = $value.IndexOf('#')
        if ($endIndex -eq -1) {
            $endIndex = $value.Length
        }

        $keyValues[$key] = $value.Substring(0, $endIndex).Trim()
        continue
    }

    if ($quoteMatches.Count -gt 1) {
        $endQuoteMatch = $quoteMatches |
            Select-Object -Skip 1 -First 1
        $keyValues[$key] = Expand-Value -Value $value.Substring(1, $endQuoteMatch.Index - 1) -QuoteCharacter $firstValueCharacter
        continue
    }

    $keyValues[$key] = Expand-Value -Value "$($value.Substring(1))`n" -QuoteCharacter $firstValueCharacter
    $foundEndQuote = $false
    while (-not $foundEndQuote) {
        $lineIndex++
        $nextLine = $lines[$lineIndex]
        $nextQuoteMatch = $nextLine |
            Select-String -Pattern $firstValueCharacter |
            Select-Object -ExpandProperty Matches -First 1
        if ($null -eq $nextQuoteMatch) {
            $keyValues[$key] += Expand-Value -Value "$nextLine`n" -QuoteCharacter $firstValueCharacter
        } else {
            $nextValue = $nextLine.Substring(0, $nextQuoteMatch.Index)
            $keyValues[$key] += Expand-Value -Value $nextValue -QuoteCharacter $firstValueCharacter
            $foundEndQuote = $true
        }
    }
}

return $keyValues
