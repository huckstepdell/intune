<#
.SYNOPSIS
    Detection script to check for unauthorized local administrators.

.DESCRIPTION
    This script checks if there are any unauthorized users in the local Administrators group.
    Compares against a whitelist of authorized administrators.

.NOTES
    This is a DETECTION script for Intune Proactive Remediations.
    Customize the $authorizedAdmins array with your organization's approved admin accounts.
    Author: Intune Admin
    Version: 1.0
#>

# Define authorized administrators (customize this list)
$authorizedAdmins = @(
    "Administrator",
    "Domain Admins",
    "Enterprise Admins"
)

try {
    # Get members of local Administrators group
    $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
    
    $unauthorizedAdmins = @()
    
    foreach ($member in $adminGroup) {
        $memberName = $member.Name.Split('\')[-1]  # Get just the username part
        
        # Check if this admin is in the authorized list
        if ($authorizedAdmins -notcontains $memberName) {
            $unauthorizedAdmins += $memberName
        }
    }
    
    if ($unauthorizedAdmins.Count -gt 0) {
        Write-Output "Unauthorized administrators found: $($unauthorizedAdmins -join ', ')"
        exit 1  # Non-compliant - trigger remediation
    } else {
        Write-Output "All administrators are authorized"
        exit 0  # Compliant
    }
    
} catch {
    Write-Error "Error checking local administrators: $_"
    exit 1
}
