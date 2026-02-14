<#
.SYNOPSIS
    Remediation script to enable BitLocker on the system drive.

.DESCRIPTION
    This script enables BitLocker encryption on the C: drive with TPM protection.
    This is a REMEDIATION script that runs when the detection script finds BitLocker is not enabled.

.NOTES
    This is a REMEDIATION script for Intune Proactive Remediations.
    Requires TPM chip and administrator privileges.
    Author: Intune Admin
    Version: 1.0
#>

try {
    # Check if TPM is available
    $tpm = Get-Tpm
    if (-not $tpm.TpmPresent) {
        Write-Error "TPM is not present on this device. BitLocker cannot be enabled."
        exit 1
    }
    
    if (-not $tpm.TpmReady) {
        Write-Error "TPM is not ready. Please check TPM status in BIOS."
        exit 1
    }
    
    # Enable BitLocker with TPM protection
    Write-Output "Enabling BitLocker on C: drive with TPM protection..."
    Enable-BitLocker -MountPoint "C:" -TpmProtector -SkipHardwareTest -ErrorAction Stop
    
    Write-Output "BitLocker has been successfully enabled on C: drive"
    exit 0
    
} catch {
    Write-Error "Error enabling BitLocker: $_"
    exit 1
}
