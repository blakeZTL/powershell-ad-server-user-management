BeforeAll {
    . $PSScriptRoot\..\Helpers\TestBootstrap.ps1
    Import-ProjectModule -ModuleName "DirectoryTools"
}

Describe "DirectoryTools\Get-GroupMemberDNs" {

    Context "Non-recursive path" {

        It "Returns group.Member values" {
            InModuleScope DirectoryTools {

                $expected = @(
                    "CN=User1,OU=Users,DC=example,DC=com",
                    "CN=User2,OU=Users,DC=example,DC=com"
                )

                function Get-ADGroup {
                    param($Identity, $Properties)
                    [pscustomobject]@{ Member = $expected }
                }

                $result = Get-GroupMemberDNs -GroupName "MyGroup"

                $result | Should -Be $expected
            }
        }

        It "Throws when group is not found" {
            InModuleScope DirectoryTools {

                function Get-ADGroup { param($Identity) $null }

                { Get-GroupMemberDNs -GroupName "MissingGroup" } |
                Should -Throw -ExpectedMessage "Group 'MissingGroup' not found."
            }
        }

        It "Does not call recursive member lookup when not recursive" {
            InModuleScope DirectoryTools {

                function Get-ADGroup { param($Identity) [pscustomobject]@{ Member = @() } }
                function Get-ADGroupMember { throw "Should not be called" }

                Get-GroupMemberDNs -GroupName "MyGroup" | Out-Null
            }
        }
    }

    Context "Recursive path" {

        It "Returns only user DistinguishedNames" {
            InModuleScope DirectoryTools {

                function Get-ADGroupMember {
                    param($Identity, [switch]$Recursive)
                    @( 
                        [pscustomobject]@{ objectClass = "user"; DistinguishedName = "CN=User1,OU=Users,DC=example,DC=com" },
                        [pscustomobject]@{ objectClass = "group"; DistinguishedName = "CN=NestedGroup,OU=Groups,DC=example,DC=com" },
                        [pscustomobject]@{ objectClass = "computer"; DistinguishedName = "CN=PC1,OU=Computers,DC=example,DC=com" },
                        [pscustomobject]@{ objectClass = "user"; DistinguishedName = "CN=User2,OU=Users,DC=example,DC=com" }
                    )
                }

                function Get-ADGroup { throw "Should not be called in -Recursive path" }

                $result = Get-GroupMemberDNs -GroupName "MyGroup" -Recursive

                $result | Should -Be @(
                    "CN=User1,OU=Users,DC=example,DC=com",
                    "CN=User2,OU=Users,DC=example,DC=com"
                )
            }
        }

        It "Calls Get-ADGroupMember with -Recursive" {
            InModuleScope DirectoryTools {

                function Get-ADGroupMember { param($Identity, [switch]$Recursive) @() }

                Get-GroupMemberDNs -GroupName "MyGroup" -Recursive | Out-Null

                $true | Should -Be $true
            }
        }
    }
}