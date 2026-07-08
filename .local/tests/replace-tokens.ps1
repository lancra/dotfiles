BeforeAll {
    . $PSScriptRoot/.testbed.ps1
    $script:sut = Get-SystemUnderTest -Path $PSCommandPath
}

Describe 'Token Replacement' {
    BeforeAll {
        $script:tokens = @{
            'FOO' = 'newfoo'
            'BAR' = 'newbar'
            'BAZ' = 'newbaz'
        }
    }

    It 'Handles single token replacements' {
        $text = @(
            '__FOO__',
            '  __FOO__  ',
            '__FOO__ Bar Baz',
            'Foo __BAR__ Baz',
            'Foo Bar __BAZ__'
        )

        $results = & $script:sut -Text $text -Token $script:tokens
        $results[0] | Should-Be -Expected 'newfoo'
        $results[1] | Should-Be -Expected '  newfoo  '
        $results[2] | Should-Be -Expected 'newfoo Bar Baz'
        $results[3] | Should-Be -Expected 'Foo newbar Baz'
        $results[4] | Should-Be -Expected 'Foo Bar newbaz'
    }

    It 'Handles multiple token replacements' {
        $text = @(
            '__FOO__ Bar __BAZ__',
            '__FOO__ __BAR__ __BAZ__'
        )

        $results = & $script:sut -Text $text -Token $script:tokens
        $results[0] | Should-Be -Expected 'newfoo Bar newbaz'
        $results[1] | Should-Be -Expected 'newfoo newbar newbaz'
    }

    It 'Preserves lines without tokens' {
        $text = @(
            'Foo Bar Baz',
            ' '
            ''
        )

        $results = & $script:sut -Text $text -Token $script:tokens
        for ($i = 0; $i -lt $results.Length; $i++) {
            $results[$i] | Should-Be -Expected $text[$i]
        }
    }

    It 'Ignores prefixes and suffixes without matches' {
        $text = @(
            '__FOO BAR__ BAZ',
            '__FOO BAR BAZ__',
            'FOO__ __BAR __BAZ QUX__'
        )

        $results = & $script:sut -Text $text -Token $script:tokens
        for ($i = 0; $i -lt $results.Length; $i++) {
            $results[$i] | Should-Be -Expected $text[$i]
        }
    }
}

Describe 'Affix Customization' {
    BeforeAll {
        $script:tokens = @{
            'FOO' = 'newfoo'
            'BAR' = 'newbar'
            'BAZ' = 'newbaz'
        }
    }

    It 'Allows affixes to be customized' {
        $text = @(
            '@@FOO@@',
            '@@FOO@@ @@BAR@@',
            '@@FOO@@ @@BAR@@ @@BAZ@@',
            'Foo @@BAR@@ Baz'
        )

        $results = & $script:sut -Text $text -Token $script:tokens -Affix '@@'
        $results[0] | Should-Be -Expected 'newfoo'
        $results[1] | Should-Be -Expected 'newfoo newbar'
        $results[2] | Should-Be -Expected 'newfoo newbar newbaz'
        $results[3] | Should-Be -Expected 'Foo newbar Baz'
    }
}
