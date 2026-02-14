<#
.SYNOPSIS
    Gets installed applications on Intune managed devices.

.DESCRIPTION
    This script retrieves a list of all applications installed on managed devices.
    Useful for inventory and compliance reporting.

.PARAMETER DeviceNamePattern
    Optional pattern to filter devices by name (supports wildcards).

.PARAMETER OutputPath
    Path where the CSV report will be saved. Defaults to current directory.

.EXAMPLE
    .\Get-InstalledApps.ps1 -OutputPath "C:\Reports\installed_apps.csv"

.EXAMPLE
    .\Get-InstalledApps.ps1 -DeviceNamePattern "LAPTOP-*"

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
    [string]$OutputPath = ".\InstalledApps_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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
    
    Write-Host "Found $($devices.Count) device(s). Retrieving installed applications..." -ForegroundColor Green
    
    $allApps = @()
    
    foreach ($device in $devices) {
        Write-Host "Processing device: $($device.deviceName)..." -ForegroundColor Cyan
        
        try {
            $deviceApps = Get-IntuneManagedDeviceDetectedApp -managedDeviceId $device.id | 
                         Select-Object @{Name='DeviceName';Expression={$device.deviceName}},
                                       @{Name='UserName';Expression={$device.userPrincipalName}},
                                       displayName,
                                       version,
                                       sizeInByte
            
            $allApps += $deviceApps
        } catch {
            Write-Warning "  Failed to get apps for $($device.deviceName): $_"
        }
    }
    
    # Export to CSV
    $allApps | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nInstalled applications exported successfully to: $OutputPath" -ForegroundColor Green
    Write-Host "Total application installations found: $($allApps.Count)" -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
