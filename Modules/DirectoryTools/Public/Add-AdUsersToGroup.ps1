
function Add-AdUsersToGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,

        [Parameter(Mandatory = $true)]
        [string[]]$UserDns,

        [bool]$DryRun = $true
    )

    $result = UserGroupManager -GroupName $GroupName -UserDns $UserDns -DryRun:$DryRun -ShouldAdd:$true

    $added = $result.Added
    $failed = $result.Failed    

    [PSCustomObject]@{
        Added  = $added
        Failed = $failed
    }
}