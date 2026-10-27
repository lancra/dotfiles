# dotnetup: begin
if (Test-Path -LiteralPath 'C:\Users\lancra\.dotnetup\dotnetup.exe' -PathType Leaf)
{
        $dotnetupScript = & 'C:\Users\lancra\.dotnetup\dotnetup.exe' env script --shell pwsh --dotnet --dotnetup | Out-String
    if (-not [string]::IsNullOrWhiteSpace($dotnetupScript))
    {
        Invoke-Expression $dotnetupScript
    }
}
# dotnetup: end
