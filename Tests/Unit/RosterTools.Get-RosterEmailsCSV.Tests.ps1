BeforeAll {
    . $PSScriptRoot\..\Helpers\TestBootstrap.ps1
    Import-ProjectModule -ModuleName "RosterTools"
}

Describe "RosterTools\Get-RosterEmailsCSV" {

    It "Reads emails from CSV given a header name" {
        InModuleScope RosterTools {

            $csv = @"
Email,Name
a@example.com,A
b@example.com,B
"@

            $path = Join-Path $TestDrive "roster.csv"
            Set-Content -Path $path -Value $csv -Encoding UTF8

            $result = Get-RosterEmailsCSV -FilePath $path -EmailColumnName "Email"

            $result | Should -Be @("a@example.com", "b@example.com")
        }
    }

    It "Throws when EmailColumnName is missing" {
        InModuleScope RosterTools {

            $csv = @"
Name
A
"@

            $path = Join-Path $TestDrive "roster.csv"
            Set-Content -Path $path -Value $csv -Encoding UTF8

            { Get-RosterEmailsCSV -FilePath $path -EmailColumnName "Email" } | Should -Throw
        }
    }

    It "Trims + removes blanks" {
        InModuleScope RosterTools {

            $csv = @"
Email
 a@example.com
     
b@example.com
"@
            $path = Join-Path $TestDrive "roster.csv"
            Set-Content -Path $path -Value $csv -Encoding UTF8

            $result = Get-RosterEmailsCSV -FilePath $path -EmailColumnName "Email"

            $result | Should -Be @("a@example.com", "b@example.com")
        }
    }
}