<#
.SYNOPSIS
    Triggers a sync for all or specific Intune managed devices.

.DESCRIPTION
    This script initiates a sync operation for Intune managed devices to force policy refresh.
    Can target all devices or filter by device name pattern.

.PARAMETER DeviceNamePattern
    Optional pattern to filter devices by name (supports wildcards).

.PARAMETER WaitBetweenSync
    Number of seconds to wait between each device sync to avoid throttling. Default is 2 seconds.

.EXAMPLE
    .\Sync-IntuneDevices.ps1
    Syncs all devices

.EXAMPLE
    .\Sync-IntuneDevices.ps1 -DeviceNamePattern "LAPTOP-*"
    Syncs only devices with names starting with "LAPTOP-"

.NOTES
    Requires Microsoft.Graph.Intune module
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceNamePattern = "*",
    
    [Parameter(Mandatory = $false)]
    [int]$WaitBetweenSync = 2
)

# Check if required module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Intune)) {
    Write-Error "Microsoft.Graph.Intune module is not installed. Install it using: Install-Module Microsoft.Graph.Intune"
    exit 1
}

try {
    # Import module
    Import-Module Microsoft.Graph.Intune -ErrorAction Stop
    
    # Connect to Microsoft Graph
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MSGraph -ErrorAction Stop
    
    # Get devices matching the pattern
    Write-Host "Retrieving devices..." -ForegroundColor Cyan
    $devices = Get-IntuneManagedDevice | Where-Object { $_.deviceName -like $DeviceNamePattern }
    
    if ($devices.Count -eq 0) {
        Write-Warning "No devices found matching pattern: $DeviceNamePattern"
        exit 0
    }
    
    Write-Host "Found $($devices.Count) device(s) to sync" -ForegroundColor Green
    
    $successCount = 0
    $failCount = 0
    
    foreach ($device in $devices) {
        try {
            Write-Host "Syncing device: $($device.deviceName)..." -ForegroundColor Cyan
            Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $device.id
            $successCount++
            Write-Host "  ✓ Sync initiated successfully" -ForegroundColor Green
        } catch {
            $failCount++
            Write-Warning "  ✗ Failed to sync: $_"
        }
        
        # Wait to avoid throttling
        if ($WaitBetweenSync -gt 0) {
            Start-Sleep -Seconds $WaitBetweenSync
        }
    }
    
    Write-Host "`nSync Summary:" -ForegroundColor Cyan
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
