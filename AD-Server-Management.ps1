Import-Module "$PSScriptRoot\Modules\DirectoryTools"
Import-Module "$PSScriptRoot\Modules\RosterTools"

Clear-Host

function Show-AppHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    $width = 72
    $border = ('=' * $width)
    $centered = ("  {0}  " -f $Title)
    $leftPad = [Math]::Max(0, [Math]::Floor(($width - $centered.Length) / 2))
    $titleLine = ((' ' * $leftPad) + $centered).PadRight($width)

    Write-Host $border -ForegroundColor DarkCyan
    Write-Host $titleLine -ForegroundColor Cyan
    Write-Host $border -ForegroundColor DarkCyan
    Write-Host ("Session Start: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Section {
    param([string]$Name)
    Write-Host ("[{0}]" -f $Name) -ForegroundColor White
}

function Write-Stat {
    param(
        [string]$Label,
        [object]$Value,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host ("  {0,-44} : {1}" -f $Label, $Value) -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-Host ("[INFO] {0}" -f $Message) -ForegroundColor DarkCyan
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host ("[WARN] {0}" -f $Message) -ForegroundColor Yellow
}

function Write-SuccessLine {
    param([string]$Message)
    Write-Host ("[OK]   {0}" -f $Message) -ForegroundColor Green
}

Show-AppHeader -Title "AD Server Management"

$configPath = "$PSScriptRoot\Config\config.psd1"
$config = Import-PowerShellDataFile -Path $configPath

Write-Section "Configuration"
Write-Info ("Using configuration from: {0}" -f $configPath)
Write-Stat "Active Directory Group Name" $config.ActiveDirectory.GroupName
Write-Stat "Membership Source File" $config.MembershipSource.FilePath
Write-Stat "Membership Source Email Column" $config.MembershipSource.EmailColumnName
Write-Stat "Membership Source Job Series Column" $config.MembershipSource.JobSeriesColumnName
Write-Stat "Membership Source Target Job Series" ($config.MembershipSource.TargetJobSeries -join ", ")
Write-Stat "Permanent Members File" $config.PermanentMembers.FilePath
Write-Stat "Permanent Members Email Column" $config.PermanentMembers.EmailColumnName
Write-Host ""

$continue = Read-Host "Continue with testing using the above configuration? (y/N)"
if ($continue -ne 'y' -and $continue -ne 'Y') {
    Write-WarnLine "Operation cancelled by user."
    exit
}

Write-Host ""
Write-Section "Current Group Snapshot"
$currentMembers = DirectoryTools\Get-GroupMemberDNs -GroupName $config.ActiveDirectory.GroupName

# Backup current members to CSV
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFolder = "$PSScriptRoot\logs"
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}
$backupPath = Join-Path $logFolder "group_members_$timestamp.csv"
$currentMembers | ForEach-Object { [PSCustomObject]@{ DistinguishedName = $_ } } | Export-Csv -Path $backupPath -NoTypeInformation
Write-Info ("Backed up {0} members to: {1}" -f $currentMembers.Count, $backupPath)

Write-Stat "Current members in group" $currentMembers.Count White
Write-Host ""

Write-Section "Roster Processing"
$employeeRoster = RosterTools\Get-RosterEmailsCSV `
    -FilePath $config.MembershipSource.FilePath `
    -EmailColumnName $config.MembershipSource.EmailColumnName `
    -JobSeriesColumnName $config.MembershipSource.JobSeriesColumnName `
    -TargetJobSeries $config.MembershipSource.TargetJobSeries
Write-Stat "Members retrieved from roster" $employeeRoster.Count

$permanentMembers = @(RosterTools\Get-RosterEmailsCSV `
        -FilePath $config.PermanentMembers.FilePath `
        -EmailColumnName $config.PermanentMembers.EmailColumnName)
Write-Stat "Permanent members retrieved" $permanentMembers.Count

$fullMemberList = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($email in $employeeRoster) { [void]$fullMemberList.Add($email) }
foreach ($email in $permanentMembers) { [void]$fullMemberList.Add($email) }
Write-Stat "Combined unique email list" $fullMemberList.Count
Write-Host ""

Write-Section "Active Directory Resolution"
$adResult = DirectoryTools\Resolve-AdUsersByEmails `
    -Emails $fullMemberList `
    -BatchSize 200 `
    -PreferActiveDirectoryModule

Write-Stat "Users found in AD" $adResult.Found.Count Green
Write-Stat "Emails not found in AD" $adResult.NotFound.Count Yellow

$membersInRosterNotInGroup = $adResult.Found | Where-Object { -not $currentMembers.Contains($_.DistinguishedName) }
$membersInGroupNotInRoster = $currentMembers | Where-Object { -not $adResult.Found.DistinguishedName.Contains($_) }
Write-Stat "Users in roster but NOT in group" $membersInRosterNotInGroup.Count Cyan
Write-Stat "Users in group but NOT in roster" $membersInGroupNotInRoster.Count Magenta
Write-Host ""

# Write-Section "Permanent Member Resolution"
# $permMemberDns = DirectoryTools\Resolve-AdUsersByEmails `
#     -Emails $permanentMembers `
#     -BatchSize 200 `
#     -PreferActiveDirectoryModule

# Write-Stat "Permanent members found in AD" $permMemberDns.Found.Count Green



$toAdd = $membersInRosterNotInGroup
$toRemove = $membersInGroupNotInRoster
Write-Stat "Users queued to add" $toAdd.Count
Write-Stat "Users queued to remove" $toRemove.Count
Write-Host ""

Write-Section "Execution Mode"
$dryRun = Read-Host "Perform a dry-run of add/remove operations? (Y/n)"
$shouldDryRun = $dryRun -eq 'Y' -or $dryRun -eq 'y' -or $dryRun -eq ''

if ($shouldDryRun) {
    Write-WarnLine "DRY RUN selected. No AD membership changes will be committed."
}
else {
    Write-WarnLine "LIVE RUN selected. AD membership changes will be applied."
}

Write-Host ""
Write-Section "Group Update Results"
$addResult = DirectoryTools\Add-AdUsersToGroup -GroupName $config.ActiveDirectory.GroupName -UserDns $toAdd -DryRun:$shouldDryRun
$removeResult = DirectoryTools\Remove-AdUsersFromGroup -GroupName $config.ActiveDirectory.GroupName -UserDns $toRemove -DryRun:$shouldDryRun

Write-Stat "Users added" $addResult.Added.Count Green
Write-Stat "Users removed" $removeResult.Removed.Count Green
Write-Host ""

Write-SuccessLine "Run complete."
