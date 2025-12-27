BeforeAll {
    . $PSScriptRoot/.testbed.ps1
    $script:sut = Get-SystemUnderTest -Path $PSCommandPath

    $directoryName = [System.IO.Path]::GetDirectoryName($PSCommandPath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
    $script:contentDirectory = Join-Path -Path $directoryName -ChildPath $fileName

    function Assert-KeyValue {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $Key,

            [Parameter()]
            [string] $Value
        )
        process {
            $keyValuesByPath.Keys | Should -Contain $Key
            $keyValuesByPath[$Key] | Should -Be $Value
            $keyValuesByContent.Keys | Should -Contain $Key
            $keyValuesByContent[$Key] | Should -Be $Value
        }
    }

    function Assert-NoKeyValue {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $Key
        )
        process {
            $keyValuesByPath.Keys | Should -Not -Contain $Key
            $keyValuesByContent.Keys | Should -Not -Contain $Key
        }
    }
}

Describe 'Single-Line Parsing' {
    BeforeAll {
        $path = Join-Path -Path $contentDirectory -ChildPath 'single-line.txt'
        $script:keyValuesByPath = & $script:sut -Path $path

        $content = Get-Content -Path $path
        $script:keyValuesByContent = & $script:sut -Content $content
    }

    It 'Handles basic key-value' {
        Assert-KeyValue -Key 'BASIC' -Value 'basic'
    }

    It 'Handles empty values' {
        Assert-KeyValue -Key 'EMPTY_VALUE' -Value ''
        Assert-KeyValue -Key 'EMPTY_SINGLE_QUOTES_VALUE' -Value ''
        Assert-KeyValue -Key 'EMPTY_DOUBLE_QUOTES_VALUE' -Value ''
        Assert-KeyValue -Key 'EMPTY_BACKTICKS_VALUE' -Value ''
    }

    It 'Handles inner quotes in values' {
        Assert-KeyValue -Key 'DOUBLE_QUOTES_IN_SINGLE_QUOTES_VALUE' -Value 'This value has "double quotes".'
        Assert-KeyValue -Key 'BACKTICKS_IN_SINGLE_QUOTES_VALUE' -Value 'This value has `backticks`.'
        Assert-KeyValue -Key 'SINGLE_QUOTES_IN_DOUBLE_QUOTES_VALUE' -Value "This value has 'single quotes'."
        Assert-KeyValue -Key 'BACKTICKS_IN_DOUBLE_QUOTES_VALUE' -Value 'This value has `backticks`.'
        Assert-KeyValue -Key 'SINGLE_QUOTES_IN_BACKTICKS_VALUE' -Value "This value has 'single quotes'."
        Assert-KeyValue -Key 'DOUBLE_QUOTES_IN_BACKTICKS_VALUE' -Value 'This value has "double quotes".'
        Assert-KeyValue -Key 'SINGLE_QUOTES_IN_UNQUOTED_VALUE' -Value "This value has 'single quotes'."
        Assert-KeyValue -Key 'DOUBLE_QUOTES_IN_UNQUOTED_VALUE' -Value 'This value has "double quotes".'
        Assert-KeyValue -Key 'BACKTICKS_IN_UNQUOTED_VALUE' -Value 'This value has `backticks`.'
    }

    It 'Trims spaces from keys' {
        Assert-KeyValue -Key 'SURROUNDING_SPACES_KEY' -Value 'spaces'
    }

    It 'Trims spaces from unquoted values' {
        Assert-KeyValue -Key 'SURROUNDING_SPACES_VALUE' -Value 'spaces'
    }

    It 'Keeps spaces around quoted values' {
        Assert-KeyValue -Key 'SURROUNDING_SPACES_VALUE_SINGLE_QUOTES' -Value '  spaces  '
        Assert-KeyValue -Key 'SURROUNDING_SPACES_VALUE_DOUBLE_QUOTES' -Value '  spaces  '
        Assert-KeyValue -Key 'SURROUNDING_SPACES_VALUE_BACKTICKS' -Value '  spaces  '
    }

    It 'Handles inner spaces in keys' {
        Assert-KeyValue -Key 'INNER SPACES KEY' -Value 'spaces'
    }

    It 'Does not expand newlines by default' {
        Assert-KeyValue -Key 'NEWLINES_VALUE' -Value 'This\nis\nnot\nmultiline.'
        Assert-KeyValue -Key 'SINGLE_QUOTE_NEWLINES_VALUE' -Value 'This\nis\nnot\nmultiline.'
        Assert-KeyValue -Key 'BACKTICK_NEWLINES_VALUE' -Value 'This\nis\nnot\nmultiline.'
    }

    It 'Expands newlines within double quotes' {
        Assert-KeyValue -Key 'DOUBLE_QUOTE_NEWLINES_VALUE' -Value "This`nis`nmultiline."
    }

    It 'Does not parse commented line' {
        Assert-NoKeyValue -Key 'COMMENT'
        Assert-NoKeyValue -Key 'COMMENT_WITH_SPACES'
    }

    It 'Handles inline comments' {
        Assert-KeyValue -Key 'INLINE_COMMENT' -Value 'value'
        Assert-KeyValue -Key 'INLINE_COMMENT_EMPTY' -Value ''
        Assert-KeyValue -Key 'INLINE_COMMENT_SPACED' -Value 'value'
        Assert-KeyValue -Key 'INLINE_COMMENT_SINGLE_QUOTES' -Value 'value in #single quotes'
        Assert-KeyValue -Key 'INLINE_COMMENT_DOUBLE_QUOTES' -Value 'value in #double quotes'
        Assert-KeyValue -Key 'INLINE_COMMENT_BACKTICKS' -Value 'value in #backticks'
    }

    It 'Handles equals in value' {
        Assert-KeyValue -Key 'EQUALS' -Value 'value=has=equals'
    }

    It 'Handles JSON value' {
        Assert-KeyValue -Key 'JSON' -Value '{ "property": "text" }'
    }
}

Describe 'Multi-Line Parsing' {
    BeforeAll {
        $path = Join-Path -Path $contentDirectory -ChildPath 'multi-line.txt'
        $script:keyValuesByPath = & $script:sut -Path $path

        $content = Get-Content -Path $path
        $script:keyValuesByContent = & $script:sut -Content $content
    }

    It 'Handles multi-line values when quoted' {
        Assert-KeyValue -Key 'SINGLE_QUOTE' -Value "This`n`"value`"`nhas`n``multiple```nlines."
        Assert-KeyValue -Key 'DOUBLE_QUOTE' -Value "This`n'value'`nhas`n``multiple```nlines."
        Assert-KeyValue -Key 'BACKTICK' -Value "This`n'value'`nhas`n`"multiple`"`nlines."
    }

    It 'Does not expand newlines by default' {
        Assert-KeyValue -Key 'SINGLE_QUOTE_NEWLINES' -Value "This\nvalue`nhas`nmultiple\nlines."
        Assert-KeyValue -Key 'BACKTICK_NEWLINES' -Value "This\nvalue`nhas`nmultiple\nlines."
    }

    It 'Expands newlines within double quotes' {
        Assert-KeyValue -Key 'DOUBLE_QUOTE_NEWLINES' -Value "This`nvalue`nhas`nmultiple`nlines."
    }

    It 'Handles inline comments' {
        Assert-KeyValue -Key 'SINGLE_QUOTE_COMMENT' -Value "Multi-line`nwith`n#single quotes."
        Assert-KeyValue -Key 'DOUBLE_QUOTE_COMMENT' -Value "Multi-line`nwith`n#double quotes."
        Assert-KeyValue -Key 'BACKTICK_COMMENT' -Value "Multi-line`nwith`n#backticks."
    }

    It 'Keeps spaces around quoted values' {
        Assert-KeyValue -Key 'SINGLE_QUOTE_SPACES' -Value "This value  `n  has extra`n  spaces.  "
        Assert-KeyValue -Key 'DOUBLE_QUOTE_SPACES' -Value "This value  `n  has extra`n  spaces.  "
        Assert-KeyValue -Key 'BACKTICK_SPACES' -Value "This value  `n  has extra`n  spaces.  "
    }
}
