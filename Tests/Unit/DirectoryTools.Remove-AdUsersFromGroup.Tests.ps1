BeforeAll {
    . $PSScriptRoot\..\Helpers\TestBootstrap.ps1
    Import-ProjectModule -ModuleName "DirectoryTools"
}

Describe "DirectoryTools\Remove-AdUsersFromGroup" {

    It "Calls UserGroupManager with ShouldAdd = $false and returns Removed/Failed" {
        InModuleScope DirectoryTools {
            $result = Remove-AdUsersFromGroup -GroupName 'MyGroup' -UserDns @('CN=User1,OU=Users,DC=example,DC=com') -DryRun:$true

            $result.Removed | Should -Be @('CN=User1,OU=Users,DC=example,DC=com')
            $result.Failed  | Should -Be @()
        }
    }

    It "Reports failures when Remove-ADGroupMember throws for some users" {
        InModuleScope DirectoryTools {
            function Remove-ADGroupMember {
                param($Identity, $Members)
                foreach ($m in @($Members)) {
                    if ($m -eq 'CN=BadUser,OU=Users,DC=example,DC=com') { throw "Simulated remove failure for $m" }
                }
            }

            $result = Remove-AdUsersFromGroup -GroupName 'MyGroup' -UserDns @(
                'CN=User1,OU=Users,DC=example,DC=com',
                'CN=BadUser,OU=Users,DC=example,DC=com'
            ) -DryRun:$false

            $result.Removed | Should -Be @('CN=User1,OU=Users,DC=example,DC=com')
            $result.Failed  | Should -Be @('CN=BadUser,OU=Users,DC=example,DC=com')
        }
    }
}
