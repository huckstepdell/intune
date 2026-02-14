# Intune Scripts Repository

A comprehensive collection of PowerShell scripts for Microsoft Intune device management, application deployment, compliance monitoring, and proactive remediation.

## 🚀 Quick Start

```powershell
# Install required module
Install-Module -Name Microsoft.Graph.Intune -Scope CurrentUser -Force

# Test your connection
.\scripts\utilities\Test-IntuneConnection.ps1

# Run your first inventory
.\scripts\device-management\Get-DeviceInventory.ps1
```

## 📁 Repository Structure

```
intune/
├── scripts/
│   ├── device-management/     # Device inventory, sync, and compliance scripts
│   ├── remediation/            # Proactive detection and remediation scripts
│   ├── app-management/         # Application deployment and inventory scripts
│   ├── utilities/              # Helper scripts and connection utilities
│   └── README.md              # Detailed documentation
├── LICENSE
└── README.md
```

## 📦 What's Included

### Device Management Scripts
- **Get-DeviceInventory.ps1** - Comprehensive device inventory export
- **Sync-IntuneDevices.ps1** - Force device sync with Intune
- **Get-NonCompliantDevices.ps1** - Identify and report non-compliant devices

### Remediation Scripts
- **BitLocker** - Detect and enable BitLocker encryption
- **Unauthorized Admins** - Detect and remove unauthorized local administrators

### Application Management Scripts
- **Get-IntuneApps.ps1** - Export all Intune-managed applications
- **Get-InstalledApps.ps1** - Inventory applications on managed devices

### Utility Scripts
- **Connect-Intune.ps1** - Simplified connection helper
- **Remove-StaleDevices.ps1** - Clean up inactive devices
- **Test-IntuneConnection.ps1** - Validate connectivity and permissions

## 📖 Documentation

For detailed usage instructions, examples, and best practices, see the [Scripts README](scripts/README.md).

## 🔐 Prerequisites

- PowerShell 5.1 or later
- Microsoft.Graph.Intune module
- Appropriate Azure AD/Intune permissions

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

These scripts are provided as-is without warranty. Always test in a non-production environment first.
