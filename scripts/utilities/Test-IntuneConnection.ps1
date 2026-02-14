<#
.SYNOPSIS
    Test script to validate Intune connectivity and permissions.

.DESCRIPTION
    This script tests connectivity to Microsoft Graph and validates that you have
    the necessary permissions to manage Intune resources. Useful for troubleshooting.

.EXAMPLE
    .\Test-IntuneConnection.ps1

.NOTES
    Requires Microsoft.Graph.Intune module
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param()

Write-Host "=== Intune Connection Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if module is installed
Write-Host "[1/5] Checking for Microsoft.Graph.Intune module..." -ForegroundColor Cyan
$intuneModule = Get-Module -ListAvailable -Name Microsoft.Graph.Intune

if ($intuneModule) {
    Write-Host "  ✓ Module installed (Version: $($intuneModule.Version))" -ForegroundColor Green
} else {
    Write-Host "  ✗ Module NOT installed" -ForegroundColor Red
    Write-Host "  Install using: Install-Module Microsoft.Graph.Intune" -ForegroundColor Yellow
    exit 1
}

# Test 2: Import module
Write-Host "[2/5] Importing module..." -ForegroundColor Cyan
try {
    Import-Module Microsoft.Graph.Intune -ErrorAction Stop
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to import module: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Connect to Microsoft Graph
Write-Host "[3/5] Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MSGraph -ErrorAction Stop
    Write-Host "  ✓ Connected successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to connect: $_" -ForegroundColor Red
    exit 1
}

# Test 4: Try to read devices
Write-Host "[4/5] Testing device read permission..." -ForegroundColor Cyan
try {
    $deviceCount = (Get-IntuneManagedDevice -ErrorAction Stop).Count
    Write-Host "  ✓ Successfully retrieved $deviceCount device(s)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to read devices: $_" -ForegroundColor Red
    Write-Host "  You may not have DeviceManagementManagedDevices.Read.All permission" -ForegroundColor Yellow
}

# Test 5: Try to read apps
Write-Host "[5/5] Testing app read permission..." -ForegroundColor Cyan
try {
    $appCount = (Get-IntuneMobileApp -ErrorAction Stop).Count
    Write-Host "  ✓ Successfully retrieved $appCount app(s)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to read apps: $_" -ForegroundColor Red
    Write-Host "  You may not have DeviceManagementApps.Read.All permission" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
