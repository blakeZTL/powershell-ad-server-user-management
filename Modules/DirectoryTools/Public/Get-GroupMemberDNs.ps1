function Get-GroupMemberDNs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName,

        [switch]$Recursive
    )

    if ($Recursive) {
        return Get-ADGroupMember -Identity $GroupName -Recursive |
        Where-Object { $_.objectClass -eq 'user' } |
        Select-Object -ExpandProperty DistinguishedName
    }

    $group = Get-ADGroup -Identity $GroupName -Properties Member
    if (-not $group) { throw "Group '$GroupName' not found." }

    return $group.Member
}