BeforeAll {
    . $PSScriptRoot\..\Helpers\TestBootstrap.ps1
    Import-ProjectModule -ModuleName "DirectoryTools"
}

Describe "DirectoryTools\Add-AdUsersToGroup" {

    It "Calls UserGroupManager with ShouldAdd = $true and returns Added/Failed" {
        InModuleScope DirectoryTools {
            $result = Add-AdUsersToGroup -GroupName 'MyGroup' -UserDns @('CN=User1,OU=Users,DC=example,DC=com') -DryRun:$true

            $result.Added | Should -Be @('CN=User1,OU=Users,DC=example,DC=com')
            $result.Failed | Should -Be @()
        }
    }

    It "Reports failures when Add-ADGroupMember throws for some users" {
        InModuleScope DirectoryTools {
            function Add-ADGroupMember {
                param($Identity, $Members)
                foreach ($m in @($Members)) {
                    if ($m -eq 'CN=BadUser,OU=Users,DC=example,DC=com') { throw "Simulated add failure for $m" }
                }
            }

            $result = Add-AdUsersToGroup -GroupName 'MyGroup' -UserDns @(
                'CN=User1,OU=Users,DC=example,DC=com',
                'CN=BadUser,OU=Users,DC=example,DC=com'
            ) -DryRun:$false

            $result.Added | Should -Be @('CN=User1,OU=Users,DC=example,DC=com')
            $result.Failed | Should -Be @('CN=BadUser,OU=Users,DC=example,DC=com')
        }
    }
}
