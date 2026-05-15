# vPro Fleet Services Intune Package

This package deploys vPro Fleet Services via Microsoft Intune.

## Prerequisites

Before creating the Intune package, you need:

1. **MSI Installer**: The vPro Fleet Services MSI installer file
   - Download `vProFleetAgent.Installer.msi` from your vPro Fleet Services tenant
   - Place the MSI file in this `source/` directory
   - The MSI file is gitignored and must be obtained separately

2. **Token File**: Authentication token for vPro Fleet Services
   - Download or copy the `PairingToken` file from your vPro Fleet Services tenant
   - Place the `PairingToken` file in this `source/` directory
   - The token file is gitignored for security reasons

## Package Structure

```
vProFleetServices/
├── package/
│   └── placeholder.txt (or .intunewin package after generation)
└── source/
    ├── vProFleetAgent.Installer.msi (gitignored - you must add this)
    ├── PairingToken (gitignored - you must create this)
    └── README.md (this file)
```

## Creating the Package

1. Obtain `vProFleetAgent.Installer.msi` and `PairingToken` from your vPro Fleet Services tenant
2. Place both files in the `source/` directory
3. Run the package generator from the repository root:
   ```powershell
   .\PackageGenerator\Create-IntunePackage.ps1 -ConfigFile .\PackageGenerator\config\vprofleetservices.json
   ```

## Installation Command

```cmd
msiexec /i "vProFleetAgent.Installer.msi" /qn /norestart
```

## Deployment in Intune

1. Create a new Windows app (Win32) in Intune
2. Upload the .intunewin package from the `package/` directory
3. Configure install command: `msiexec /i "vProFleetAgent.Installer.msi" /qn /norestart`
4. Configure uninstall command: Use MSI product code (check MSI properties)
5. Configure detection rule:
   - Type: MSI
   - MSI product code: (extract from vProFleetAgent.Installer.msi)
6. Set requirements (OS version, architecture, etc.)
7. Assign to target groups

## Notes

- The MSI and token files are excluded from version control via .gitignore
- The MSI filename must be `vProFleetAgent.Installer.msi`
- The token filename must be `PairingToken`
- Ensure PairingToken contains only the token value (no extra whitespace or newlines)
- Test the deployment in a non-production environment first
- Use Get-MSICodes.ps1 (in repository root) to extract the product code from the MSI if needed
