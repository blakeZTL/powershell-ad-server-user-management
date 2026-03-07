
function Remove-AdUsersFromGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter(Mandatory = $true)]
        [string[]]$UserDns,

        [bool]$DryRun = $true
    )

    $result = UserGroupManager -GroupName $GroupName -UserDns $UserDns -DryRun:$DryRun -ShouldAdd:$false

    $removed = $result.Removed
    $failed = $result.Failed    

    [PSCustomObject]@{
        Removed = $removed
        Failed  = $failed
    }
}