<#
.SYNOPSIS
    Detection script to check if Windows Update service is running.

.DESCRIPTION
    This script checks if the Windows Update service is running and set to automatic startup.
    Returns exit code 0 if compliant, 1 if non-compliant.

.NOTES
    This is a DETECTION script for Intune Proactive Remediations.
    Author: Intune Admin
    Version: 1.0
#>

try {
    # Get Windows Update service
    $wuService = Get-Service -Name wuauserv -ErrorAction Stop
    
    # Check if service is running and set to automatic
    if ($wuService.Status -eq "Running" -and $wuService.StartType -eq "Automatic") {
        Write-Output "Windows Update service is running and set to automatic"
        exit 0  # Compliant
    } else {
        Write-Output "Windows Update service is not running or not set to automatic. Status: $($wuService.Status), StartType: $($wuService.StartType)"
        exit 1  # Non-compliant - trigger remediation
    }
    
} catch {
    Write-Error "Error checking Windows Update service: $_"
    exit 1  # Non-compliant due to error
}
