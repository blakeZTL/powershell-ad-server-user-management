
function UserGroupManager {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter(Mandatory = $true)]
        [string[]]$UserDns,

        [bool]$DryRun = $true,

        [bool]$ShouldAdd = $true
    )

    $added = [System.Collections.Generic.List[string]]::new()
    $removed = [System.Collections.Generic.List[string]]::new()
    $failed = [System.Collections.Generic.List[string]]::new()

    foreach ($dn in $UserDns) {
        try {
            if ($ShouldAdd) {
                if ($DryRun) {
                    Write-Verbose "DRY RUN: Would add user '$dn' to group '$GroupName'."
                }
                else {
                    Add-ADGroupMember -Identity $GroupName -Members $dn -ErrorAction Stop
                    Write-Verbose "Successfully added user '$dn' to group '$GroupName'."
                }   
                $added.Add($dn) | Out-Null
            }
            else {
                if ($DryRun) {
                    Write-Verbose "DRY RUN: Would remove user '$dn' from group '$GroupName'."
                }
                else {
                    Remove-ADGroupMember -Identity $GroupName -Members $dn -ErrorAction Stop
                    Write-Verbose "Successfully removed user '$dn' from group '$GroupName'."
                }
                $removed.Add($dn) | Out-Null
            }
        }
        catch {
            Write-Error "Failed to modify membership for user '$dn' in group '$GroupName'. Error: $_"
            $failed.Add($dn) | Out-Null
        }
    }

    [PSCustomObject]@{
        Added   = $added
        Removed = $removed
        Failed  = $failed
    }
}
