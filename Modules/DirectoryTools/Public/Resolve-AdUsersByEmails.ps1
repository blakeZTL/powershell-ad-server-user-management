function Resolve-AdUsersByEmails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]$Emails,

        [int]$BatchSize = 200,

        [switch]$PreferActiveDirectoryModule
    )

    if ($PreferActiveDirectoryModule -and (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        # Still batch to avoid huge -Filter strings
        $found = New-Object System.Collections.Generic.List[object]
        $foundEmailSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        # Normalize emails, remove blanks, de-dupe case-insensitively
        $emailSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($e in @($Emails)) {
            if ($null -eq $e) { continue }
            $t = $e.ToString().Trim()
            if ([string]::IsNullOrWhiteSpace($t)) { continue }
            [void]$emailSet.Add($t)
        }

        $normalized = @($emailSet)

        for ($offset = 0; $offset -lt $normalized.Count; $offset += $BatchSize) {
            $batch = $normalized[$offset..([math]::Min($offset + $BatchSize - 1, $normalized.Count - 1))]

            # Build a Filter like: (mail -eq 'a' -or userPrincipalName -eq 'a' -or mail -eq 'b' ...)
            $parts = foreach ($email in $batch) {
                $safe = $email.Replace("'", "''")
                "mail -eq '$safe' -or userPrincipalName -eq '$safe'"
            }
            $filter = "(" + ($parts -join " -or ") + ")"

            $users = Get-ADUser -Filter $filter -Properties mail, userPrincipalName, displayName, distinguishedName, samAccountName, objectGuid
            foreach ($u in $users) {
                if ($u.mail -and $emailSet.Contains($u.mail)) { [void]$foundEmailSet.Add($u.mail) }
                if ($u.userPrincipalName -and $emailSet.Contains($u.userPrincipalName)) { [void]$foundEmailSet.Add($u.userPrincipalName) }

                $found.Add([PSCustomObject]@{
                        Mail              = $u.mail
                        UserPrincipalName = $u.userPrincipalName
                        SamAccountName    = $u.samAccountName
                        DisplayName       = $u.displayName
                        DistinguishedName = $u.distinguishedName
                        ObjectGuid        = $u.objectGuid
                    }) | Out-Null
            }
        }

        $notFound = New-Object System.Collections.Generic.List[string]
        foreach ($email in $normalized) { if (-not $foundEmailSet.Contains($email)) { $notFound.Add($email) | Out-Null } }

        return [PSCustomObject]@{ Found = $found; NotFound = $notFound }
    }

    # Fallback: LDAP (no dependency)
    return Get-AdUsersByEmailsBatch -Emails $Emails -BatchSize $BatchSize
}