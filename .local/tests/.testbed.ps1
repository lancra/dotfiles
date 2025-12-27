function Get-SystemUnderTest {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    process {
        $uri = [uri]::new($Path)
        $segments = $uri.Segments |
            Select-Object -Skip 1 |
            ForEach-Object {
                return $_ -eq 'tests/' `
                    ? 'bin/'
                    : $_
            }

        $segments -join ''
    }
}
