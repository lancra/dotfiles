Import-Module 'Lance'
Get-ChildItem -Path "$env:BIN/powershell/profile" -Filter '*.ps1' -Recurse |
    ForEach-Object {
        . $_
    }
