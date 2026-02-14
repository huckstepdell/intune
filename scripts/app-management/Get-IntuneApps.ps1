<#
.SYNOPSIS
    Gets all applications deployed via Intune.

.DESCRIPTION
    This script retrieves all applications from Intune including Win32 apps, 
    Microsoft Store apps, and built-in apps. Exports details to CSV.

.PARAMETER OutputPath
    Path where the CSV report will be saved. Defaults to current directory.

.PARAMETER AppType
    Filter by application type: All, Win32, StoreApp, BuiltIn. Default is All.

.EXAMPLE
    .\Get-IntuneApps.ps1 -OutputPath "C:\Reports\apps.csv"

.EXAMPLE
    .\Get-IntuneApps.ps1 -AppType Win32

.NOTES
    Requires Microsoft.Graph.Intune module
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\IntuneApps_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Win32", "StoreApp", "BuiltIn")]
    [string]$AppType = "All"
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
    
    # Get applications based on type
    Write-Host "Retrieving applications..." -ForegroundColor Cyan
    
    $apps = @()
    
    switch ($AppType) {
        "Win32" {
            $apps = Get-IntuneWin32App | Select-Object displayName, publisher, @{Name='Type';Expression={'Win32'}}, fileName, size, createdDateTime
        }
        "StoreApp" {
            $apps = Get-IntuneMobileApp | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.microsoftStoreForBusinessApp' } | 
                    Select-Object displayName, publisher, @{Name='Type';Expression={'Store App'}}, createdDateTime
        }
        "BuiltIn" {
            $apps = Get-IntuneMobileApp | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.iosVppApp' -or $_.'@odata.type' -eq '#microsoft.graph.androidManagedStoreApp' } | 
                    Select-Object displayName, publisher, @{Name='Type';Expression={'Built-In'}}, createdDateTime
        }
        default {
            # Get all apps
            $apps = Get-IntuneMobileApp | Select-Object displayName, publisher, '@odata.type', createdDateTime
        }
    }
    
    # Export to CSV
    $apps | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Applications exported successfully to: $OutputPath" -ForegroundColor Green
    Write-Host "Total applications found: $($apps.Count)" -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred: $_"
    exit 1
}
