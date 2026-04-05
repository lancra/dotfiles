[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [psobject] $Image
)

$tagsByDigest = @{}
$url = "https://hub.docker.com/v2/namespaces/$($Image.Namespace)/repositories/$($Image.Repository)/tags?page_size=100"
do {
    $response = & curl --silent $url |
        ConvertFrom-Json

    $response |
        Select-Object -ExpandProperty 'results' |
        ForEach-Object {
            $digest = $_.digest ?? $_.images[0].digest

            if (-not $tagsByDigest.ContainsKey($digest)) {
                $tagsByDigest[$digest] = @()
            }

            if ($_.name -eq 'latest') {
                $tagsByDigest['@latest'] = $digest
            }

            $tagsByDigest[$digest] += ,$_.name
        }

    $url = $response |
        Select-Object -ExpandProperty 'next'
}
while ($null -ne $url)

$tagsByDigest
