<#
.SYNOPSIS
    Removes stale devices from Intune.

.DESCRIPTION
    This script identifies and optionally removes devices that haven't synced with Intune
    for a specified number of days. Useful for cleaning up inactive devices.

.PARAMETER DaysInactive
    Number of days of inactivity before considering a device stale. Default is 90 days.

.PARAMETER RemoveDevices
    If specified, actually removes the devices. Without this flag, script runs in report-only mode.

.PARAMETER OutputPath
    Path where the CSV report will be saved. Defaults to current directory.

.EXAMPLE
    .\Remove-StaleDevices.ps1 -DaysInactive 90
    Reports stale devices without removing them

.EXAMPLE
    .\Remove-StaleDevices.ps1 -DaysInactive 90 -RemoveDevices
    Removes devices inactive for 90+ days

.NOTES
    Requires Microsoft.Graph.Intune module
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$DaysInactive = 90,
    
    [Parameter(Mandatory = $false)]
    [switch]$RemoveDevices,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\StaleDevices_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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
    
    # Calculate cutoff date
    $cutoffDate = (Get-Date).AddDays(-$DaysInactive)
    
    Write-Host "Searching for devices inactive since: $($cutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
    
    # Get all devices
    $allDevices = Get-IntuneManagedDevice
    
    # Filter stale devices
    $staleDevices = $allDevices | Where-Object { 
        $_.lastSyncDateTime -and ([DateTime]$_.lastSyncDateTime) -lt $cutoffDate 
    } | Select-Object deviceName, userPrincipalName, lastSyncDateTime, operatingSystem, complianceState, id
    
    if ($staleDevices.Count -eq 0) {
        Write-Host "No stale devices found!" -ForegroundColor Green
        exit 0
    }
    
    # Export report
    $staleDevices | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "`nFound $($staleDevices.Count) stale device(s)" -ForegroundColor Yellow
    Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
    
    if ($RemoveDevices) {
        Write-Host "`nRemoving stale devices..." -ForegroundColor Yellow
        
        $removeCount = 0
        $failCount = 0
        
        foreach ($device in $staleDevices) {
            try {
                Write-Host "  Removing: $($device.deviceName) (Last sync: $($device.lastSyncDateTime))..." -ForegroundColor Cyan
                Remove-IntuneManagedDevice -managedDeviceId $device.id -ErrorAction Stop
                $removeCount++
                Write-Host "    ✓ Removed successfully" -ForegroundColor Green
            } catch {
                $failCount++
                Write-Warning "    ✗ Failed to remove: $_"
            }
            
            # Small delay to avoid throttling
            Start-Sleep -Milliseconds 500
        }
        
        Write-Host "`nRemoval Summary:" -ForegroundColor Cyan
        Write-Host "  Successfully removed: $removeCount" -ForegroundColor Green
        Write-Host "  Failed to remove: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
    } else {
        Write-Host "`nRunning in REPORT-ONLY mode. Use -RemoveDevices to actually remove these devices." -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
