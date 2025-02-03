Import-Module 'Lance'
Get-ChildItem -Path "$env:HOME/.local/bin/powershell/profile" -Filter '*.ps1' |
    ForEach-Object {
        . $_
    }
