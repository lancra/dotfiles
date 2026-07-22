BeforeAll {
    . $PSScriptRoot/../.testbed.ps1
    $script:sut = Get-SystemUnderTest -Path $PSCommandPath

    function New-ConflictTestFile {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter()]
            [string] $Content
        )
        process {
            $directory = [System.IO.Path]::GetTempPath()
            $path = Join-Path -Path $directory -ChildPath "resolve-conflict.test.$((New-Guid).Guid).txt"
            Set-Content -Path $path -Value $Content
            return $path
        }
    }

    function Invoke-ConflictTest {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string] $Content,

            [Parameter()]
            [string] $Specification,

            [Parameter()]
            [scriptblock] $Assertion
        )
        process {
            try {
                $path = New-ConflictTestFile -Content $Content
                & $script:sut -Path $path -Specification $Specification
                & $Assertion -Content (Get-Content -Path $path)
            }
            finally {
                Remove-Item -Path $path
            }
        }
    }

    $script:simpleContent = @"
<<<<<<<
Ours Index 0
Ours Index 1
Ours Index 2
Ours Index 3
Ours Index 4
Ours Index 5
Ours Index 6
Ours Index 7
Ours Index 8
Ours Index 9
|||||||
Index 0
Index 1
Index 2
Index 3
Index 4
Index 5
Index 6
Index 7
Index 8
Index 9
=======
Theirs Index 0
Theirs Index 1
Theirs Index 2
Theirs Index 3
Theirs Index 4
Theirs Index 5
Theirs Index 6
Theirs Index 7
Theirs Index 8
Theirs Index 9
>>>>>>>
"@

    $script:longContent = @"
<<<<<<<
Ours Index 0
Ours Index 1
Ours Index 2
Ours Index 3
Ours Index 4
Ours Index 5
Ours Index 6
Ours Index 7
Ours Index 8
Ours Index 9
Ours Index 10
Ours Index 11
Ours Index 12
Ours Index 13
Ours Index 14
Ours Index 15
Ours Index 16
Ours Index 17
Ours Index 18
Ours Index 19
=======
Theirs Index 0
Theirs Index 1
Theirs Index 2
Theirs Index 3
Theirs Index 4
Theirs Index 5
Theirs Index 6
Theirs Index 7
Theirs Index 8
Theirs Index 9
Theirs Index 10
Theirs Index 11
Theirs Index 12
Theirs Index 13
Theirs Index 14
Theirs Index 15
Theirs Index 16
Theirs Index 17
Theirs Index 18
Theirs Index 19
>>>>>>>
"@
}

Describe 'Single Target' {
    It 'Supports single index from ours target' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<2'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content | Should-Be 'Ours Index 2'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports single index from theirs target' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '>3'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content | Should-Be 'Theirs Index 3'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports index range from ours target' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<1-3'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 3
                $Content[0] | Should-Be 'Ours Index 1'
                $Content[1] | Should-Be 'Ours Index 2'
                $Content[2] | Should-Be 'Ours Index 3'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports index range from theirs target' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '>0-3'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 4
                $Content[0] | Should-Be 'Theirs Index 0'
                $Content[1] | Should-Be 'Theirs Index 1'
                $Content[2] | Should-Be 'Theirs Index 2'
                $Content[3] | Should-Be 'Theirs Index 3'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports multi-digit index from target' {
        $arguments = @{
            Content = $script:longContent
            Specification = '<12'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content | Should-Be 'Ours Index 12'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports multi-digit index range from target' {
        $arguments = @{
            Content = $script:longContent
            Specification = '>12-15'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 4
                $Content[0] | Should-Be 'Theirs Index 12'
                $Content[1] | Should-Be 'Theirs Index 13'
                $Content[2] | Should-Be 'Theirs Index 14'
                $Content[3] | Should-Be 'Theirs Index 15'
            }
        }

        Invoke-ConflictTest @arguments
    }
}
Describe 'Multiple Targets' {
    It 'Supports single index from both targets' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<2>3'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 2
                $Content[0] | Should-Be 'Ours Index 2'
                $Content[1] | Should-Be 'Theirs Index 3'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports index range from both targets' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<2-4>3-6'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 7
                $Content[0] | Should-Be 'Ours Index 2'
                $Content[1] | Should-Be 'Ours Index 3'
                $Content[2] | Should-Be 'Ours Index 4'
                $Content[3] | Should-Be 'Theirs Index 3'
                $Content[4] | Should-Be 'Theirs Index 4'
                $Content[5] | Should-Be 'Theirs Index 5'
                $Content[6] | Should-Be 'Theirs Index 6'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports mixture of indexes and index ranges from both targets' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<2>3-4'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 3
                $Content[0] | Should-Be 'Ours Index 2'
                $Content[1] | Should-Be 'Theirs Index 3'
                $Content[2] | Should-Be 'Theirs Index 4'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports multi-digit index from both targets' {
        $arguments = @{
            Content = $script:longContent
            Specification = '<12>15'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 2
                $Content[0] | Should-Be 'Ours Index 12'
                $Content[1] | Should-Be 'Theirs Index 15'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports multi-digit index range from both targets' {
        $arguments = @{
            Content = $script:longContent
            Specification = '>12-13<15-16'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 4
                $Content[0] | Should-Be 'Theirs Index 12'
                $Content[1] | Should-Be 'Theirs Index 13'
                $Content[2] | Should-Be 'Ours Index 15'
                $Content[3] | Should-Be 'Ours Index 16'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports arbitrary number of target specifiers' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '>0<1>2<3>4<5>6-7<8-9'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 10
                $Content[0] | Should-Be 'Theirs Index 0'
                $Content[1] | Should-Be 'Ours Index 1'
                $Content[2] | Should-Be 'Theirs Index 2'
                $Content[3] | Should-Be 'Ours Index 3'
                $Content[4] | Should-Be 'Theirs Index 4'
                $Content[5] | Should-Be 'Ours Index 5'
                $Content[6] | Should-Be 'Theirs Index 6'
                $Content[7] | Should-Be 'Theirs Index 7'
                $Content[8] | Should-Be 'Ours Index 8'
                $Content[9] | Should-Be 'Ours Index 9'
            }
        }

        Invoke-ConflictTest @arguments
    }
}

Describe 'Globbing' {
    It 'Supports glob from single target' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<*'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 10
                $Content[0] | Should-Be 'Ours Index 0'
                $Content[1] | Should-Be 'Ours Index 1'
                $Content[2] | Should-Be 'Ours Index 2'
                $Content[3] | Should-Be 'Ours Index 3'
                $Content[4] | Should-Be 'Ours Index 4'
                $Content[5] | Should-Be 'Ours Index 5'
                $Content[6] | Should-Be 'Ours Index 6'
                $Content[7] | Should-Be 'Ours Index 7'
                $Content[8] | Should-Be 'Ours Index 8'
                $Content[9] | Should-Be 'Ours Index 9'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports glob from both targets' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<*>*'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 20
                $Content[0] | Should-Be 'Ours Index 0'
                $Content[1] | Should-Be 'Ours Index 1'
                $Content[2] | Should-Be 'Ours Index 2'
                $Content[3] | Should-Be 'Ours Index 3'
                $Content[4] | Should-Be 'Ours Index 4'
                $Content[5] | Should-Be 'Ours Index 5'
                $Content[6] | Should-Be 'Ours Index 6'
                $Content[7] | Should-Be 'Ours Index 7'
                $Content[8] | Should-Be 'Ours Index 8'
                $Content[9] | Should-Be 'Ours Index 9'
                $Content[10] | Should-Be 'Theirs Index 0'
                $Content[11] | Should-Be 'Theirs Index 1'
                $Content[12] | Should-Be 'Theirs Index 2'
                $Content[13] | Should-Be 'Theirs Index 3'
                $Content[14] | Should-Be 'Theirs Index 4'
                $Content[15] | Should-Be 'Theirs Index 5'
                $Content[16] | Should-Be 'Theirs Index 6'
                $Content[17] | Should-Be 'Theirs Index 7'
                $Content[18] | Should-Be 'Theirs Index 8'
                $Content[19] | Should-Be 'Theirs Index 9'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports glob for index range end from single target' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<7-*'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 3
                $Content[0] | Should-Be 'Ours Index 7'
                $Content[1] | Should-Be 'Ours Index 8'
                $Content[2] | Should-Be 'Ours Index 9'
            }
        }

        Invoke-ConflictTest @arguments
    }

    It 'Supports glob for index range end from both targets' {
        $arguments = @{
            Content = $script:simpleContent
            Specification = '<7-*>6-*'
            Assertion = {
                param(
                    [Parameter(ValueFromPipeline)]
                    [string[]] $Content
                )
                $Content.Length | Should-Be 7
                $Content[0] | Should-Be 'Ours Index 7'
                $Content[1] | Should-Be 'Ours Index 8'
                $Content[2] | Should-Be 'Ours Index 9'
                $Content[3] | Should-Be 'Theirs Index 6'
                $Content[4] | Should-Be 'Theirs Index 7'
                $Content[5] | Should-Be 'Theirs Index 8'
                $Content[6] | Should-Be 'Theirs Index 9'
            }
        }

        Invoke-ConflictTest @arguments
    }
}

Describe 'Detailed' {
    It 'Outputs resolution details' {
        $content = @"
<<<<<<<
Ours Index 0
Ours Index 1
Ours Index 2
=======
Theirs Index 0
Theirs Index 1
Theirs Index 2
>>>>>>>
"@
        $expectedDetails = @(
            '--------------',
            '<<<<<<<',
            'Ours Index 0',
            'Ours Index 1',
            'Ours Index 2',
            '=======',
            'Theirs Index 0',
            'Theirs Index 1',
            'Theirs Index 2',
            '>>>>>>>',
            '--------------',
            '<1>1-2',
            '--------------',
            'Ours Index 1',
            'Theirs Index 1',
            'Theirs Index 2',
            '--------------'
        )

        try {
            $path = New-ConflictTestFile -Content $content
            $output = & $script:sut -Path $path -Specification '<1>1-2' -Detailed
            $output | Should-BeCollection $expectedDetails
        }
        finally {
            Remove-Item -Path $path
        }
    }
}
