<#
.SYNOPSIS
    Connects to Microsoft Graph for Intune management.

.DESCRIPTION
    This helper script provides a simple way to connect to Microsoft Graph with appropriate scopes
    for Intune management. Can be dot-sourced in other scripts.

.PARAMETER Scopes
    Array of permission scopes to request. Defaults to common Intune scopes.

.PARAMETER UseDeviceCode
    Use device code flow for authentication (useful for scripts).

.EXAMPLE
    .\Connect-Intune.ps1

.EXAMPLE
    . .\Connect-Intune.ps1
    # Dot-source to use in other scripts

.NOTES
    Requires Microsoft.Graph.Intune or Microsoft.Graph modules
    Author: Intune Admin
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Scopes = @(
        "DeviceManagementManagedDevices.ReadWrite.All",
        "DeviceManagementApps.ReadWrite.All",
        "DeviceManagementConfiguration.ReadWrite.All",
        "DeviceManagementServiceConfig.ReadWrite.All"
    ),
    
    [Parameter(Mandatory = $false)]
    [switch]$UseDeviceCode
)

function Test-IntuneModule {
    $intuneModule = Get-Module -ListAvailable -Name Microsoft.Graph.Intune
    $graphModule = Get-Module -ListAvailable -Name Microsoft.Graph
    
    if (-not $intuneModule -and -not $graphModule) {
        Write-Error "Neither Microsoft.Graph.Intune nor Microsoft.Graph module is installed."
        Write-Host "Install one using:" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph.Intune" -ForegroundColor Cyan
        Write-Host "  OR" -ForegroundColor Yellow
        Write-Host "  Install-Module Microsoft.Graph" -ForegroundColor Cyan
        return $false
    }
    return $true
}

try {
    if (-not (Test-IntuneModule)) {
        exit 1
    }
    
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    
    # Try Microsoft.Graph.Intune first
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) {
        Import-Module Microsoft.Graph.Intune -ErrorAction Stop
        
        if ($UseDeviceCode) {
            Connect-MSGraph -UseDeviceAuthentication -ErrorAction Stop
        } else {
            Connect-MSGraph -ErrorAction Stop
        }
        
        Write-Host "✓ Successfully connected to Microsoft Graph (via Intune module)" -ForegroundColor Green
    }
    # Fall back to Microsoft.Graph
    elseif (Get-Module -ListAvailable -Name Microsoft.Graph) {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        
        if ($UseDeviceCode) {
            Connect-MgGraph -Scopes $Scopes -UseDeviceCode -ErrorAction Stop
        } else {
            Connect-MgGraph -Scopes $Scopes -ErrorAction Stop
        }
        
        Write-Host "✓ Successfully connected to Microsoft Graph" -ForegroundColor Green
        
        # Display context (only available with Microsoft.Graph module)
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            Write-Host "`nConnection Details:" -ForegroundColor Cyan
            Write-Host "  Account: $($context.Account)" -ForegroundColor White
            Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor White
        }
    }
    
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    exit 1
}
