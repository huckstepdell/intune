<#
.SYNOPSIS
    Gets comprehensive device inventory from Intune.

.DESCRIPTION
    This script retrieves detailed device information from Microsoft Intune including hardware specs,
    OS version, compliance status, and last sync time. Exports results to CSV.

.PARAMETER OutputPath
    Path where the CSV report will be saved. Defaults to current directory.

.EXAMPLE
    .\Get-DeviceInventory.ps1 -OutputPath "C:\Reports\devices.csv"

.NOTES
    Requires Microsoft.Graph.Intune module
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\DeviceInventory_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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
    
    # Get all managed devices
    Write-Host "Retrieving device information..." -ForegroundColor Cyan
    $devices = Get-IntuneManagedDevice | Select-Object `
        deviceName,
        managedDeviceOwnerType,
        operatingSystem,
        osVersion,
        manufacturer,
        model,
        serialNumber,
        emailAddress,
        userPrincipalName,
        complianceState,
        lastSyncDateTime,
        enrolledDateTime,
        managementAgent,
        totalStorageSpaceInBytes,
        freeStorageSpaceInBytes
    
    # Export to CSV
    $devices | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Device inventory exported successfully to: $OutputPath" -ForegroundColor Green
    Write-Host "Total devices found: $($devices.Count)" -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
