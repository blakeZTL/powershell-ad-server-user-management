# AD Server User Management

PowerShell project for maintaining Active Directory group membership from roster-based source data.

The workflow:

1. Reads roster emails from CSV files.
2. Resolves those emails to AD users.
3. Compares desired users with current group members.
4. Adds missing users and removes users no longer in scope.
5. Creates a timestamped backup snapshot of current group members before changes.

## What This Repository Includes

- Main orchestration script: AD-Server-Management.ps1
- Config-driven inputs: Config/config.psd1
- AD helper module: Modules/DirectoryTools
- Roster parsing module: Modules/RosterTools
- Unit tests (Pester): Tests/Unit
- Backup snapshots: logs/

## Prerequisites

- Windows environment with access to your Active Directory domain.
- PowerShell 5.1 or PowerShell 7+.
- Active Directory cmdlets available for direct AD operations:
  - Get-ADGroup
  - Get-ADGroupMember
  - Get-ADUser
  - Add-ADGroupMember
  - Remove-ADGroupMember
- Permissions to read target AD users and modify membership for the configured AD group.
- Pester (for tests).

Example install for test dependency:

```powershell
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
```

## Quick Start

1. Open a PowerShell terminal in the repository root.
2. Review and update configuration in Config/config.psd1.
3. Ensure input CSV files exist and column names match config values.
4. Run:

```powershell
.\AD-Server-Management.ps1
```

5. Confirm prompts:
   - Continue prompt after configuration preview.
   - Dry-run prompt (recommended first).

## Configuration

Main settings live in Config/config.psd1.

Key sections:

- ActiveDirectory
  - GroupName: target AD group to manage.
- MembershipSource
  - FilePath: source roster CSV.
  - EmailColumnName: email column used to resolve AD users.
  - JobSeriesColumnName: job series column used for filtering.
  - TargetJobSeries: allowed job series values.
- PermanentMembers
  - FilePath: CSV of always-included members.
  - EmailColumnName: email column name in the permanent members file.

Current example:

```powershell
@{
		ActiveDirectory  = @{
				GroupName = 'GROUP_NAME'
		}

		MembershipSource = @{
				FilePath            = '.\Employee Roster.csv'
				EmailColumnName     = 'Email Address Work'
				JobSeriesColumnName = 'Occupational Series'
				TargetJobSeries     = @('123', '456')
		}

		PermanentMembers = @{
				FilePath        = '.\PermanentMembers.csv'
				EmailColumnName = 'Email'
		}
}
```

## Runtime Behavior

When you run AD-Server-Management.ps1, it performs:

1. Displays loaded configuration values.
2. Loads current members from the configured AD group.
3. Writes a backup snapshot to logs/group_members_yyyy-MM-dd_HH-mm-ss.csv.
4. Reads roster and permanent member emails.
5. Builds a unique desired email set.
6. Resolves emails to AD users via:
   - ActiveDirectory module path when available and requested.
   - LDAP fallback path otherwise.
7. Computes:
   - Users in roster but not in group (to add).
   - Users in group but not in roster (to remove).
8. Executes add/remove operations in dry-run or live mode.
9. Prints result counts.

## Modules and Public Commands

DirectoryTools module:

- Get-GroupMemberDNs
  - Returns Distinguished Names for members of a target AD group.
- Resolve-AdUsersByEmails
  - Resolves emails/UPNs to AD users with batching.
  - Supports ActiveDirectory cmdlets and LDAP fallback.
- Get-AdUsersByEmailBatch
  - LDAP-based batch resolver used as fallback.
- Add-AdUsersToGroup
  - Adds DNs to a group (or simulates in dry-run).
- Remove-AdUsersFromGroup
  - Removes DNs from a group (or simulates in dry-run).

RosterTools module:

- Get-RosterEmailsCSV
  - Reads emails from CSV.
  - Supports either a custom Filter scriptblock or JobSeries filtering.
  - Trims values and deduplicates emails case-insensitively.

## Testing

Run all unit tests:

```powershell
Invoke-Pester -Path .\Tests\Unit
```

Run a single test file example:

```powershell
Invoke-Pester -Path .\Tests\Unit\Resolve-AdUsersByEmails.Tests.ps1
```

Test bootstrap helper:

- Tests/Helpers/TestBootstrap.ps1 imports local module paths directly and validates expected module names.

## Safety and Operational Notes

- Always run dry-run mode first in a new environment or after config changes.
- Confirm source CSV header names exactly match configured column names.
- Keep the backup files in logs/ so membership can be restored manually if needed.
- Validate AD permissions before live run.
- Large email sets are batched to avoid oversized filters.

## Troubleshooting

- AD cmdlets not found:
  - Install RSAT/AD module and verify Get-ADUser is available.
- CSV column errors:
  - Ensure exact header text in CSV matches config.
- Missing users in AD:
  - Review NotFound output from Resolve-AdUsersByEmails.
- Unexpected removals:
  - Recheck filtering criteria in MembershipSource and PermanentMembers inputs.

## Suggested Workflow

1. Update roster and permanent member CSV files.
2. Review Config/config.psd1.
3. Run AD-Server-Management.ps1 in dry-run mode.
4. Validate planned add/remove counts.
5. Run again in live mode when output is correct.
