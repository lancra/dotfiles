[CmdletBinding()]
param()

$isWinGetInstalled = $null -ne (Get-Command -Name 'winget' -ErrorAction SilentlyContinue)
if (-not $isWinGetInstalled) {
    throw "Install WinGet Preview before attempting to clone the repository."
}

$isGitInstalled = $null -ne (Get-Command -Name 'git' -ErrorAction SilentlyContinue)
if (-not $isGitInstalled) {
    Write-Output 'Installing Git.'
    winget install --exact --id Git.Git
}

$isPowerShellCoreInstalled = $null -ne (Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue)
if (-not $isPowerShellCoreInstalled) {
    Write-Output 'Installing PowerShell Core.'
    winget install --exact --id Microsoft.PowerShell
}

git clone https://github.com/lancra/dotfiles.git $HOME/repo

@('.config', '.git', '.gitconfig', '.local') |
    ForEach-Object {
        Move-Item -Path "$HOME/$_" -Destination "$HOME/"
    }

Remove-Item -Path $HOME/repo -Recurse -Force

git -C $HOME restore (git ls-files -d)
git -C $HOME st
