Import-Module 'Lance'
Get-ChildItem -Path "$env:BIN/powershell/profile" -Filter '*.ps1' |
    ForEach-Object {
        . $_
    }
