[CmdletBinding()]
param()

$lines = @(Get-Clipboard)

$dateGroupName = 'date'
$descriptionGroupName = 'description'
$accountGroupName = 'account'
$amountGroupName = 'amount'
$pattern = "(?<$dateGroupName>.*?) (?<$descriptionGroupName>.*?) (?<$accountGroupName>x....) (?<$amountGroupName>.*)"

function Get-GroupValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Text.RegularExpressions.Match] $Source,

        [Parameter(Mandatory)]
        [string] $Name
    )
    process {
        $Source |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $Name |
            Select-Object -ExpandProperty Value
    }
}

$lines |
    ForEach-Object {
        $lineMatch = $_.Trim() |
            Select-String -Pattern $pattern |
            Select-Object -ExpandProperty Matches

        [pscustomobject]@{
            Date = Get-GroupValue -Source $lineMatch -Name $dateGroupName
            Description = Get-GroupValue -Source $lineMatch -Name $descriptionGroupName
            Account = Get-GroupValue -Source $lineMatch -Name $accountGroupName
            Amount = Get-GroupValue -Source $lineMatch -Name $amountGroupName
        }
    } |
    ConvertTo-Csv -Delimiter "`t" -UseQuotes AsNeeded |
    Set-Clipboard
