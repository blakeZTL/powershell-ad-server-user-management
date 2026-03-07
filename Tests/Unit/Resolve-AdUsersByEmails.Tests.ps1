BeforeAll {
    . $PSScriptRoot\..\Helpers\TestBootstrap.ps1
    Import-ProjectModule -ModuleName "DirectoryTools"
}

Describe "DirectoryTools\Resolve-AdUsersByEmails" {

    Context "PreferActiveDirectoryModule path" {

        BeforeEach {
            # Pretend the AD module cmdlet exists
            Mock Get-Command { return @{ Name = "Get-ADUser" } } -ParameterFilter { $Name -eq "Get-ADUser" }
        }

        It "Normalizes input (trim), removes blanks/nulls, de-dupes case-insensitively, and returns Found/NotFound" {
            InModuleScope DirectoryTools {

                # Return ONE AD user that matches one of the normalized emails
                Mock Get-ADUser {
                    @(
                        [pscustomobject]@{
                            mail              = "a@example.com"
                            userPrincipalName = $null
                            samAccountName    = "a1"
                            displayName       = "User A"
                            distinguishedName = "CN=UserA,DC=x,DC=y"
                            objectGuid        = [guid]::NewGuid()
                        }
                    )
                }

                # Input includes: whitespace, duplicates in different case, blanks, null
                $emails = @(
                    " a@example.com ",
                    "A@EXAMPLE.COM",
                    "   ",
                    "",
                    $null,
                    "b@example.com"
                )

                

                $result = Resolve-AdUsersByEmails -Emails $emails -PreferActiveDirectoryModule -BatchSize 200

                # Found contains the AD result
                $result.Found.Count | Should -Be 1
                $result.Found[0].SamAccountName | Should -Be "a1"

                # NotFound should include b@example.com only (a is found, blanks removed, dupes removed)
                $result.NotFound | Should -Be @("b@example.com")
            }
        }

        It "Batches filters and calls Get-ADUser once per batch" {
            InModuleScope DirectoryTools {

                # Return nothing; we only care about call count
                Mock Get-ADUser { @() }

                # 5 unique emails, BatchSize 2 => 3 calls (2 + 2 + 1)
                $emails = @("a@x.com", "b@x.com", "c@x.com", "d@x.com", "e@x.com")

                Resolve-AdUsersByEmails -Emails $emails -PreferActiveDirectoryModule -BatchSize 2 | Out-Null

                Should -Invoke Get-ADUser -Times 3 -Exactly
            }
        }

        It "Matches FoundEmailSet using either mail or userPrincipalName" {
            InModuleScope DirectoryTools {

                Mock Get-ADUser {
                    @(
                        # match via UPN
                        [pscustomobject]@{
                            mail              = $null
                            userPrincipalName = "upn1@example.com"
                            samAccountName    = "u1"
                            displayName       = "User 1"
                            distinguishedName = "CN=U1,DC=x,DC=y"
                            objectGuid        = [guid]::NewGuid()
                        },
                        # match via mail
                        [pscustomobject]@{
                            mail              = "mail2@example.com"
                            userPrincipalName = $null
                            samAccountName    = "u2"
                            displayName       = "User 2"
                            distinguishedName = "CN=U2,DC=x,DC=y"
                            objectGuid        = [guid]::NewGuid()
                        }
                    )
                }

                $emails = @("upn1@example.com", "mail2@example.com", "missing@example.com")

                $result = Resolve-AdUsersByEmails -Emails $emails -PreferActiveDirectoryModule -BatchSize 200

                $result.Found.Count | Should -Be 2
                $result.NotFound | Should -Be @("missing@example.com")
            }
        }

        It "Does NOT call fallback when PreferActiveDirectoryModule is set and Get-ADUser exists" {
            InModuleScope DirectoryTools {

                Mock Get-ADUser { @() }
                Mock Get-AdUsersByEmailsBatch { throw "Fallback should not be called" }

                Resolve-AdUsersByEmails -Emails @("a@x.com") -PreferActiveDirectoryModule | Out-Null
            }
        }
    }

    Context "Fallback (LDAP) path" {

        It "Calls Get-AdUsersByEmailsBatch when PreferActiveDirectoryModule is NOT set" {
            InModuleScope DirectoryTools {

                Mock Get-AdUsersByEmailsBatch { "fallback-called" }

                $result = Resolve-AdUsersByEmails -Emails @("a@x.com")

                $result | Should -Be "fallback-called"
                Should -Invoke Get-AdUsersByEmailsBatch -Times 1 -Exactly
            }
        }

        It "Calls Get-AdUsersByEmailsBatch when PreferActiveDirectoryModule is set but Get-ADUser is not available" {
            InModuleScope DirectoryTools {

                Mock Get-Command { return $null } -ParameterFilter { $Name -eq "Get-ADUser" }
                Mock Get-AdUsersByEmailsBatch { "fallback-called" }

                $result = Resolve-AdUsersByEmails -Emails @("a@x.com") -PreferActiveDirectoryModule

                $result | Should -Be "fallback-called"
                Should -Invoke Get-AdUsersByEmailsBatch -Times 1 -Exactly
            }
        }

        It "Handles large email lists via batching" {
            InModuleScope DirectoryTools {

                Mock Get-ADUser { @() }

                $emails = 1..1000 | ForEach-Object { "user$_@example.com" }

                Resolve-AdUsersByEmails -Emails $emails -PreferActiveDirectoryModule -BatchSize 200 | Out-Null

                Should -Invoke Get-ADUser -Times 5
            }
        }

        It "De-duplicates emails case-insensitively" {
            InModuleScope DirectoryTools {

                Mock Get-ADUser { @() }

                $emails = @(
                    "USER@example.com",
                    "user@example.com",
                    "User@example.com"
                )

                $result = Resolve-AdUsersByEmails -Emails $emails -PreferActiveDirectoryModule

                $result.NotFound.Count | Should -Be 1
            }
        }
    }
}