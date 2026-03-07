function Get-AdUsersByEmailsBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Emails,

        # Batch size: 150–300 is a good range to avoid overly long LDAP filters.
        [int]$BatchSize = 200,

        # Optional: target a specific DC
        [string]$Server,

        # Optional: override search base DN
        [string]$SearchBase
    )

    function ConvertTo-LdapFilterValue([string]$value) {
        # RFC4515 escaping: \ * ( ) NUL
        $value -replace '\\', '\5c' `
            -replace '\*', '\2a' `
            -replace '\(', '\28' `
            -replace '\)', '\29' `
            -replace '\x00', '\00'
    }

    # Normalize emails, remove blanks, de-dupe case-insensitively
    $emailSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $Emails) {
        if ($null -eq $e) { continue }
        $t = $e.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        [void]$emailSet.Add($t)
    }

    $normalizedEmails = $emailSet.ToArray()

    # Prepare outputs
    $found = New-Object System.Collections.Generic.List[object]
    $foundEmailSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Build LDAP RootDSE to get default naming context if SearchBase not provided
    $rootPath = if ($Server) { "LDAP://$Server/RootDSE" } else { "LDAP://RootDSE" }
    $rootDse = New-Object System.DirectoryServices.DirectoryEntry($rootPath)
    $defaultNc = $rootDse.Properties["defaultNamingContext"][0]
    $baseDn = if ($SearchBase) { $SearchBase } else { $defaultNc }

    $searchPath = if ($Server) { "LDAP://$Server/$baseDn" } else { "LDAP://$baseDn" }
    $entry = New-Object System.DirectoryServices.DirectoryEntry($searchPath)

    # Chunk emails into batches
    for ($offset = 0; $offset -lt $normalizedEmails.Count; $offset += $BatchSize) {

        $batch = $normalizedEmails[$offset..([math]::Min($offset + $BatchSize - 1, $normalizedEmails.Count - 1))]

        # Build OR filter with both mail and UPN checks.
        # Resulting filter example:
        # (&(objectCategory=person)(objectClass=user)(|(mail=a@b.com)(userPrincipalName=a@b.com)(mail=c@d.com)...))
        $orParts = New-Object System.Text.StringBuilder
        foreach ($email in $batch) {
            $esc = ConvertTo-LdapFilterValue $email
            [void]$orParts.Append("(mail=$esc)")
            [void]$orParts.Append("(userPrincipalName=$esc)")
        }

        $filter = "(&(objectCategory=person)(objectClass=user)(|$($orParts.ToString())))"

        $searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
        $searcher.PageSize = 1000
        $searcher.SizeLimit = 0
        $searcher.Filter = $filter

        $null = $searcher.PropertiesToLoad.AddRange(@(
                "distinguishedName",
                "samAccountName",
                "userPrincipalName",
                "mail",
                "displayName",
                "objectGuid"
            ))

        foreach ($result in $searcher.FindAll()) {
            $p = $result.Properties

            $mail = ($p["mail"] | Select-Object -First 1)
            $upn = ($p["userprincipalname"] | Select-Object -First 1)

            # Mark found emails by matching either mail or UPN back to the input set
            if ($mail -and $emailSet.Contains($mail)) { [void]$foundEmailSet.Add($mail) }
            if ($upn -and $emailSet.Contains($upn)) { [void]$foundEmailSet.Add($upn) }

            $objGuid = $null
            if ($p["objectguid"] -and $p["objectguid"].Count -gt 0) {
                $objGuid = [Guid]$p["objectguid"][0]
            }

            $found.Add([PSCustomObject]@{
                    Mail              = $mail
                    UserPrincipalName = $upn
                    SamAccountName    = ($p["samaccountname"] | Select-Object -First 1)
                    DisplayName       = ($p["displayname"] | Select-Object -First 1)
                    DistinguishedName = ($p["distinguishedname"] | Select-Object -First 1)
                    ObjectGuid        = $objGuid
                }) | Out-Null
        }
    }

    # Build NotFound list in original normalized form
    $notFound = New-Object System.Collections.Generic.List[string]
    foreach ($email in $normalizedEmails) {
        if (-not $foundEmailSet.Contains($email)) {
            $notFound.Add($email) | Out-Null
        }
    }

    [PSCustomObject]@{
        Found    = $found
        NotFound = $notFound
    }
}