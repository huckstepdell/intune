# intune
Intune App Scripts

## Overview

This repository contains scripts and configurations for packaging applications for deployment via Microsoft Intune. It includes the PackageGenerator tool for creating `.intunewin` packages and various application configurations.

## Important Note

**⚠️ Installers Not Included**

This repository does **NOT** include actual installer files (`.exe`, `.msi`, etc.). You must provide these files yourself:

- Download installers from official vendor sources
- Place them in the appropriate `installers\<AppName>\source\` folders
- Ensure you have proper licensing for any software you deploy

The repository provides:
- ✅ Folder structure and organization
- ✅ Configuration files for packaging
- ✅ Scripts and tools for creating Intune packages
- ✅ Detection scripts
- ❌ Actual installer binaries (you must obtain these separately)

## Repository Structure

```
intune\
├── installers\           # Application source files (installers not included)
│   ├── Microsoft\
│   │   └── RSAT\         # RSAT installation scripts
│   ├── Template\         # Template for new applications
│   ├── winget\           # Generic winget package installer scripts
│   └── ...               # Other apps (not tracked in Git)
├── PackageGenerator\     # Tool for creating .intunewin packages
│   ├── Create-IntunePackage.ps1
│   ├── config\           # Application configurations
│   └── README.md         # Detailed usage instructions
└── logos\                # (not tracked in Git)
```

## Getting Started

1. **Clone this repository**
2. **Download required installers** from official sources and place in appropriate folders (or use the generic winget scripts)
3. **Add IntuneWinAppUtil.exe** to the PackageGenerator folder ([download here](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool))
4. **Review PackageGenerator documentation** at [PackageGenerator/README.md](PackageGenerator/README.md)
5. **Run the packaging script** to create Intune packages

## Winget Package Scripts

The repository includes **generic winget scripts** that can install/uninstall **any** Windows Package Manager (winget) package without needing installer files. These scripts are ideal for deploying applications available in the winget repository.

### Features

- **Universal**: Works with any package in the winget repository
- **Version Management**: Install specific versions or always use latest
- **Intelligent Updates**: Automatically handles version upgrades/downgrades
- **System Context**: Runs in SYSTEM context for Intune deployments
- **Comprehensive Logging**: All operations logged to `C:\Windows\Logs\Software\`

### Scripts Included

**In `installers\winget\source\`** (packaged for deployment):

1. **install-winget-package.ps1** - Install or upgrade a winget package
   - Installs specified version or latest
   - Automatically uninstalls different versions if specific version required
   - Skips installation if correct version already present

2. **uninstall-winget-package.ps1** - Uninstall a winget package
   - Clean removal of packages
   - Idempotent (safe to run multiple times)

**In `installers\winget\`** (detection template):

3. **_detect-winget-package copy.ps1** - Template detection script for Intune
   - **Copy this template for each application**
   - Customize the default `PackageId` and `RequiredVersion` parameters
   - Use as custom detection script in Intune
   - Not included in the `.intunewin` package

### How to Use

#### Step 1: Create Winget Intune Package (Once)

Create the winget `.intunewin` package **one time** using PackageGenerator:

1. The package is already configured at `installers\winget\`
2. Run PackageGenerator and select "Winget Package Manager"
3. This creates a reusable `.intunewin` package containing the install/uninstall scripts

**You only need to create this package once** - it can be reused for any winget-based application.

#### Step 2: Customize Detection Script (Per Application)

For each application you want to deploy, copy `_detect-winget-package copy.ps1` and update the default parameter values:

```powershell
# Example: detect-git.git.ps1
[CmdletBinding()]
Param(
    [string]$PackageId       = "Git.Git",          # ← Change this
    [string]$RequiredVersion = "Latest",           # ← Change this or use specific version
    [string]$Source          = "winget"
)
```

Save with a descriptive name matching the PackageId (e.g., `detect-git.git.ps1`, `detect-Microsoft.PowerShell.ps1`).

#### Step 3: Create Win32 App in Intune (Per Application)

For each application:

1. **Upload Package**: Use the same winget `.intunewin` package created in Step 1

2. **Install Command**: Specify the PackageId and Version for this app
   ```
   powershell.exe -ExecutionPolicy Bypass -File "install-winget-package.ps1" -PackageId "Git.Git" -Version "Latest"
   ```

3. **Uninstall Command**: Specify the PackageId for this app
   ```
   powershell.exe -ExecutionPolicy Bypass -File "uninstall-winget-package.ps1" -PackageId "Git.Git"
   ```

4. **Detection Method**: Use custom script
   - Upload your app-specific customized detection script (e.g., `detect-git.git.ps1`)
   - The script uses the default parameter values you set
   - Returns exit code 0 if detected, 1 if not detected

#### Key Benefits of This Approach

- **One package, many apps**: Create the `.intunewin` package once, reuse for all winget-based deployments
- **Simple configuration**: Just change PackageId/Version in commands for each app
- **Easy maintenance**: Update the winget package once to update all deployments

### Finding Package IDs

To find winget package IDs:
```powershell
winget search "Application Name"
```

Example output:
```
Name            Id                    Version
----------------------------------------------
Git             Git.Git               2.43.0
PowerShell      Microsoft.PowerShell  7.4.1
```

Use the **Id** column value (e.g., `Git.Git`) as the `PackageId` parameter.

### Template Structure

The `installers\winget\` folder contains the universal scripts, and `installers\Template\` provides a starting point for new applications.

For applications deployed via winget, you would:
1. Create a folder structure similar to `installers\Template\` (optional - mainly needed if you have additional files)
2. Copy and customize the `_detect-winget-package copy.ps1` template
3. Use the generic winget `.intunewin` package with customized commands

### Advantages

✅ **No installer files needed** - Packages downloaded directly from winget
✅ **Always up-to-date** - Use "Latest" to automatically get newest versions
✅ **Version control** - Pin to specific versions when needed
✅ **Bandwidth efficient** - No need to store installer files in repository
✅ **Automatic updates** - Scripts handle version migrations intelligently
✅ **Comprehensive logging** - Full audit trail in `C:\Windows\Logs\Software\`
✅ **Template-based** - One detection script template for all winget packages

## Quick Links

- [PackageGenerator Documentation](PackageGenerator/README.md) - Detailed guide for creating Intune packages
- [Microsoft Intune Documentation](https://docs.microsoft.com/en-us/mem/intune/)
- [Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)

## License

See [LICENSE](LICENSE) file for details.
