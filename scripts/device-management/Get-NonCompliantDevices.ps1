<#
.SYNOPSIS
    Gets all non-compliant devices from Intune.

.DESCRIPTION
    This script retrieves all devices that are not compliant with Intune policies
    and exports the results to CSV with detailed information.

.PARAMETER OutputPath
    Path where the CSV report will be saved. Defaults to current directory.

.PARAMETER SendEmail
    If specified, sends an email notification with the report.

.EXAMPLE
    .\Get-NonCompliantDevices.ps1 -OutputPath "C:\Reports\noncompliant.csv"

.NOTES
    Requires Microsoft.Graph.Intune module
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\NonCompliantDevices_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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
    
    # Get non-compliant devices
    Write-Host "Retrieving non-compliant devices..." -ForegroundColor Cyan
    $nonCompliantDevices = Get-IntuneManagedDevice | Where-Object { $_.complianceState -ne "compliant" } | Select-Object `
        deviceName,
        userPrincipalName,
        emailAddress,
        complianceState,
        operatingSystem,
        osVersion,
        lastSyncDateTime,
        manufacturer,
        model,
        serialNumber,
        managedDeviceOwnerType
    
    if ($nonCompliantDevices.Count -eq 0) {
        Write-Host "No non-compliant devices found! All devices are compliant." -ForegroundColor Green
        exit 0
    }
    
    # Export to CSV
    $nonCompliantDevices | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nNon-compliant devices report:" -ForegroundColor Yellow
    Write-Host "  Total non-compliant devices: $($nonCompliantDevices.Count)" -ForegroundColor Red
    Write-Host "  Report exported to: $OutputPath" -ForegroundColor Green
    
    # Group by compliance state
    $groupedByState = $nonCompliantDevices | Group-Object complianceState
    Write-Host "`nBreakdown by compliance state:" -ForegroundColor Cyan
    foreach ($group in $groupedByState) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
