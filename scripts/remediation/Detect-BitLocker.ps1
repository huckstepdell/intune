<#
.SYNOPSIS
    Detection script to check if BitLocker is enabled on the system drive.

.DESCRIPTION
    This script checks if BitLocker encryption is enabled on the C: drive.
    Returns exit code 0 if BitLocker is enabled (compliant), 1 if not enabled (non-compliant).
    
    Use with a remediation script to enable BitLocker if not already enabled.

.NOTES
    This is a DETECTION script for Intune Proactive Remediations.
    Author: Intune Admin
    Version: 1.0
#>

try {
    # Get BitLocker status for C: drive
    $bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    
    if ($bitlockerStatus.ProtectionStatus -eq "On") {
        Write-Output "BitLocker is enabled and protection is ON"
        exit 0  # Compliant
    } else {
        Write-Output "BitLocker is NOT enabled or protection is OFF"
        exit 1  # Non-compliant - trigger remediation
    }
    
} catch {
    Write-Error "Error checking BitLocker status: $_"
    exit 1  # Non-compliant due to error
}
