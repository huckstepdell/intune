<#
.SYNOPSIS
    Remediation script to remove unauthorized local administrators.

.DESCRIPTION
    This script removes unauthorized users from the local Administrators group.
    Only removes users not in the authorized list.

.NOTES
    This is a REMEDIATION script for Intune Proactive Remediations.
    CAUTION: Test thoroughly before deployment to avoid locking out legitimate admins.
    Author: Intune Admin
    Version: 1.0
#>

# Define authorized administrators (must match detection script)
$authorizedAdmins = @(
    "Administrator",
    "Domain Admins",
    "Enterprise Admins"
)

try {
    # Get members of local Administrators group
    $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
    
    $removedAdmins = @()
    
    foreach ($member in $adminGroup) {
        $memberName = $member.Name.Split('\')[-1]  # Get just the username part
        
        # Check if this admin is NOT in the authorized list
        if ($authorizedAdmins -notcontains $memberName) {
            try {
                Remove-LocalGroupMember -Group "Administrators" -Member $member.Name -ErrorAction Stop
                $removedAdmins += $memberName
                Write-Output "Removed unauthorized admin: $memberName"
            } catch {
                Write-Warning "Failed to remove $memberName : $_"
            }
        }
    }
    
    if ($removedAdmins.Count -gt 0) {
        Write-Output "Successfully removed $($removedAdmins.Count) unauthorized administrator(s): $($removedAdmins -join ', ')"
        exit 0
    } else {
        Write-Output "No unauthorized administrators to remove"
        exit 0
    }
    
} catch {
    Write-Error "Error removing unauthorized administrators: $_"
    exit 1
}
