<#
.SYNOPSIS
    Remediation script to start and configure Windows Update service.

.DESCRIPTION
    This script ensures the Windows Update service is started and set to automatic startup.
    Runs when the detection script finds the service is not running or not automatic.

.NOTES
    This is a REMEDIATION script for Intune Proactive Remediations.
    Author: Intune Admin
    Version: 1.0
#>

try {
    # Get Windows Update service
    $wuService = Get-Service -Name wuauserv -ErrorAction Stop
    
    # Set service to automatic if not already (AutomaticDelayedStart is also acceptable)
    if ($wuService.StartType -notmatch "Automatic") {
        Write-Output "Setting Windows Update service to automatic startup..."
        Set-Service -Name wuauserv -StartupType Automatic -ErrorAction Stop
    }
    
    # Start service if not running
    if ($wuService.Status -ne "Running") {
        Write-Output "Starting Windows Update service..."
        Start-Service -Name wuauserv -ErrorAction Stop
    }
    
    # Verify the fix
    $wuService = Get-Service -Name wuauserv -ErrorAction Stop
    if ($wuService.Status -eq "Running" -and $wuService.StartType -match "Automatic") {
        Write-Output "Windows Update service successfully started and configured"
        exit 0
    } else {
        Write-Error "Failed to configure Windows Update service properly"
        exit 1
    }
    
} catch {
    Write-Error "Error configuring Windows Update service: $_"
    exit 1
}
