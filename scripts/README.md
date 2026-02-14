# Intune Scripts Repository

A collection of PowerShell scripts for Microsoft Intune device management, application deployment, and compliance monitoring.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Script Categories](#script-categories)
  - [Device Management](#device-management)
  - [Remediation Scripts](#remediation-scripts)
  - [Application Management](#application-management)
  - [Utilities](#utilities)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- PowerShell 5.1 or later
- Microsoft.Graph.Intune PowerShell module
- Appropriate Intune/Azure AD permissions:
  - DeviceManagementManagedDevices.ReadWrite.All
  - DeviceManagementApps.ReadWrite.All
  - DeviceManagementConfiguration.ReadWrite.All
  - DeviceManagementServiceConfig.ReadWrite.All

### Installing Required Modules

```powershell
Install-Module -Name Microsoft.Graph.Intune -Scope CurrentUser -Force
```

## Installation

1. Clone this repository:
```bash
git clone https://github.com/huckstepdell/intune.git
cd intune
```

2. Test your Intune connection:
```powershell
.\scripts\utilities\Test-IntuneConnection.ps1
```

## Script Categories

### Device Management

Scripts for managing and reporting on Intune-managed devices.

#### Get-DeviceInventory.ps1
Retrieves comprehensive device information from Intune including hardware specs, OS version, compliance status, and last sync time.

**Usage:**
```powershell
.\scripts\device-management\Get-DeviceInventory.ps1 -OutputPath "C:\Reports\devices.csv"
```

**Output:** CSV file with device details including:
- Device name and serial number
- Operating system and version
- Manufacturer and model
- Compliance state
- Last sync date/time
- Storage information

#### Sync-IntuneDevices.ps1
Triggers a sync operation for Intune managed devices to force policy refresh.

**Usage:**
```powershell
# Sync all devices
.\scripts\device-management\Sync-IntuneDevices.ps1

# Sync specific devices by name pattern
.\scripts\device-management\Sync-IntuneDevices.ps1 -DeviceNamePattern "LAPTOP-*"
```

**Parameters:**
- `DeviceNamePattern` - Filter devices by name (supports wildcards)
- `WaitBetweenSync` - Seconds to wait between syncs (default: 2)

#### Get-NonCompliantDevices.ps1
Retrieves all devices that are not compliant with Intune policies and exports detailed information.

**Usage:**
```powershell
.\scripts\device-management\Get-NonCompliantDevices.ps1 -OutputPath "C:\Reports\noncompliant.csv"
```

**Output:** CSV file with non-compliant device details and compliance state breakdown.

### Remediation Scripts

Proactive remediation scripts for detecting and fixing common issues. Deploy these through Intune's "Proactive Remediations" feature.

#### BitLocker Remediation
**Detection:** `Detect-BitLocker.ps1`
- Checks if BitLocker is enabled on the C: drive
- Exit 0 = Compliant, Exit 1 = Non-compliant

**Remediation:** `Remediate-BitLocker.ps1`
- Enables BitLocker with TPM protection
- Requires TPM chip present and ready

**Usage:**
Deploy via Intune Portal → Devices → Scripts & Remediations → Proactive Remediations

#### Unauthorized Admins Remediation
**Detection:** `Detect-UnauthorizedAdmins.ps1`
- Checks for unauthorized users in local Administrators group
- Compares against whitelist

**Remediation:** `Remediate-UnauthorizedAdmins.ps1`
- Removes unauthorized administrators
- ⚠️ **CAUTION:** Test thoroughly before deployment

**Configuration:**
Customize the `$authorizedAdmins` array in both scripts:
```powershell
$authorizedAdmins = @(
    "Administrator",
    "Domain Admins",
    "YourCompanyAdmin"
)
```

### Application Management

Scripts for managing applications in Intune.

#### Get-IntuneApps.ps1
Retrieves all applications deployed via Intune.

**Usage:**
```powershell
# Get all apps
.\scripts\app-management\Get-IntuneApps.ps1

# Get only Win32 apps
.\scripts\app-management\Get-IntuneApps.ps1 -AppType Win32
```

**Parameters:**
- `OutputPath` - Path for CSV export
- `AppType` - Filter: All, Win32, StoreApp, BuiltIn

#### Get-InstalledApps.ps1
Retrieves applications installed on managed devices for inventory and compliance reporting.

**Usage:**
```powershell
# Get apps for all devices
.\scripts\app-management\Get-InstalledApps.ps1

# Get apps for specific devices
.\scripts\app-management\Get-InstalledApps.ps1 -DeviceNamePattern "LAPTOP-*"
```

### Utilities

Helper scripts for common tasks.

#### Connect-Intune.ps1
Provides a simple way to connect to Microsoft Graph with appropriate Intune scopes.

**Usage:**
```powershell
# Interactive connection
.\scripts\utilities\Connect-Intune.ps1

# Device code flow (for automation)
.\scripts\utilities\Connect-Intune.ps1 -UseDeviceCode

# Dot-source for use in other scripts
. .\scripts\utilities\Connect-Intune.ps1
```

#### Remove-StaleDevices.ps1
Identifies and optionally removes devices that haven't synced with Intune for a specified period.

**Usage:**
```powershell
# Report only (no removal)
.\scripts\utilities\Remove-StaleDevices.ps1 -DaysInactive 90

# Remove stale devices
.\scripts\utilities\Remove-StaleDevices.ps1 -DaysInactive 90 -RemoveDevices
```

**Parameters:**
- `DaysInactive` - Number of days before considering a device stale (default: 90)
- `RemoveDevices` - Switch to actually remove devices (without this, report-only mode)

#### Test-IntuneConnection.ps1
Tests connectivity to Microsoft Graph and validates permissions.

**Usage:**
```powershell
.\scripts\utilities\Test-IntuneConnection.ps1
```

**Tests:**
1. Module installation
2. Module import
3. Graph connection
4. Device read permissions
5. App read permissions

## Usage Examples

### Daily Device Compliance Check
```powershell
# Connect to Intune
.\scripts\utilities\Connect-Intune.ps1

# Get non-compliant devices
.\scripts\device-management\Get-NonCompliantDevices.ps1 -OutputPath "C:\Reports\Daily_$(Get-Date -Format 'yyyyMMdd').csv"
```

### Monthly Cleanup
```powershell
# Remove devices inactive for 90+ days (report mode)
.\scripts\utilities\Remove-StaleDevices.ps1 -DaysInactive 90

# Review the report, then remove if approved
.\scripts\utilities\Remove-StaleDevices.ps1 -DaysInactive 90 -RemoveDevices
```

### Device Inventory Report
```powershell
# Get complete device inventory
.\scripts\device-management\Get-DeviceInventory.ps1 -OutputPath "C:\Reports\Inventory_$(Get-Date -Format 'yyyyMMdd').csv"

# Get app inventory
.\scripts\app-management\Get-IntuneApps.ps1 -OutputPath "C:\Reports\Apps_$(Get-Date -Format 'yyyyMMdd').csv"
```

## Best Practices

### Security
- ✅ Never embed credentials or secrets in scripts
- ✅ Use managed identities or service principals for automation
- ✅ Review and test all scripts in a non-production environment first
- ✅ Follow principle of least privilege for permissions

### Script Execution
- ✅ Run scripts with appropriate execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- ✅ Test on a small subset of devices before broad deployment
- ✅ Use `-WhatIf` parameter when available
- ✅ Monitor script execution through Intune portal

### Remediation Scripts
- ✅ Always test detection scripts independently first
- ✅ Ensure detection logic exactly matches remediation logic
- ✅ Use error handling (`try-catch`) in all scripts
- ✅ Log meaningful output for troubleshooting
- ✅ Consider running in user vs. system context carefully

### Reporting
- ✅ Schedule regular reports using Task Scheduler or Azure Automation
- ✅ Store reports in a centralized location
- ✅ Archive old reports appropriately
- ✅ Use consistent naming conventions with timestamps

## Troubleshooting

### Common Issues

**"Module not found"**
```powershell
Install-Module -Name Microsoft.Graph.Intune -Scope CurrentUser -Force
```

**"Insufficient permissions"**
- Ensure your account has the required Graph API permissions
- Contact your Azure AD administrator to grant permissions

**"Unable to connect to Graph"**
- Check network connectivity
- Verify proxy settings if applicable
- Ensure multi-factor authentication is completed

**"Execution policy error"**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with a clear description

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**⚠️ Important Disclaimer**

These scripts are provided as-is without warranty. Always test scripts in a non-production environment before deploying to production. The authors are not responsible for any issues that may arise from using these scripts.
