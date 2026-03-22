[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string] $Name,

    [Parameter()]
    [ValidateSet('BuiltIn', 'Executable', 'Module', 'Script')]
    [string] $Kind
)

$script:profileAliasModuleName = 'HackF5.ProfileAlias.Generated'
$script:powershellAliases = Get-Content -Path "$env:XDG_CONFIG_HOME/powershell/aliases.json" |
    ConvertFrom-Json

enum AliasKind {
    BuiltIn
    Executable
    Module
    Script
}

class Alias {
    [string] $Key
    [string] $Module
    [string] $Command
    [string] $Definition
    [AliasKind] $Kind

    Alias([System.Management.Automation.AliasInfo] $aliasInfo) {
        $this.Key = $aliasInfo.Name
        $this.Module = $aliasInfo.ModuleName
        $this.Command = $this.Module -and $this.Module -eq $script:profileAliasModuleName `
            ? [Alias]::ResolveProfileAliasCommand($this.Key) `
            : $aliasInfo.ResolvedCommandName
        $this.Definition = $aliasInfo.Definition
        $this.Kind = [Alias]::ResolveKind($this.Command, $this.Module)
    }

    [string] GetDetails() {
        switch ($this.Kind) {
            ([AliasKind]::BuiltIn) { return "`e[33mBuilt-In`e[39m" }
            ([AliasKind]::Executable) { return "`e[31mExecutable`e[39m" }
            ([AliasKind]::Module) { return "`e[34mModule`e[39m $($this.Module)" }
            ([AliasKind]::Script) {
                $directory = [System.IO.Path]::GetDirectoryName($this.Definition)
                return "`e[32mScript`e[39m in $directory"
            }
        }

        return ''
    }

    hidden static [string] ResolveProfileAliasCommand([string] $key) {
        $aliasCommand = $script:powershellAliases |
            Select-Object -ExpandProperty $key |
            Select-Object -ExpandProperty 'command'
        return "``$aliasCommand``"
    }

    hidden static [AliasKind] ResolveKind([string] $command, [string] $module) {
        if (-not [string]::IsNullOrEmpty($module)) {
                return [AliasKind]::Module
            } elseif ($command.EndsWith('.exe')) {
                return [AliasKind]::Executable
            } elseif ($command.EndsWith('.ps1')) {
                return [AliasKind]::Script
            } else {
                return [AliasKind]::BuiltIn
            }
    }
}

$getAliasArguments = @{}
if ($Name) {
    $getAliasArguments['Name'] = $Name
}
Get-Alias @getAliasArguments |
    ForEach-Object {
        [Alias]::new($_)
    } |
    Where-Object { -not $Kind -or $_.Kind -eq $Kind } |
    Sort-Object -Property Key |
    ForEach-Object {
        "$($_.Key) -> $($_.Command) ($($_.GetDetails()))"
    }
