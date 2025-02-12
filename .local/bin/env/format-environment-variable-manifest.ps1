[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string] $Yaml
)

$Yaml | & yq --input-format 'yaml' '.. style="single"'
