# NVIDIA Sync Installer for Intune

This folder deploys NVIDIA Sync via Intune Win32 app deployment using the vendor's EXE installer directly (no wrapper install/uninstall scripts).

**⚠️ This is a placeholder scaffold.** The following need to be confirmed/filled in before packaging:

- Place the vendor's NVIDIA Sync setup EXE in this `source` folder
- `detect-nvidiasync.ps1`: `$DisplayNameFilter` (currently `*NVIDIA Sync*`) - confirm the actual registry DisplayName
- Confirm the EXE's silent install/uninstall switches for the Intune commands below

## Files

### Source
- **NvidiaSyncSetup.exe** - The vendor's installer (place here; used directly as the Intune install/uninstall command)
- **detect-nvidiasync.ps1** - Detection script that checks the registry for NVIDIA Sync installation

### Package
- **NvidiaSync.intunewin** - The packaged .intunewin file (generated using IntuneWinAppUtil.exe)

## Installation Details

- **Install Context**: System (runs as SYSTEM)
- **Logs**:
  - Detect log: `C:\Windows\Logs\Software\NvidiaSync-detect.log`

## Creating the .intunewin Package

Use the Microsoft Win32 Content Prep Tool (or `PackageGenerator\Create-IntunePackage.ps1`):

```powershell
.\IntuneWinAppUtil.exe `
    -c "installers\NvidiaSync\source" `
    -s "NvidiaSyncSetup.exe" `
    -o "installers\NvidiaSync\package"
```

## Intune Configuration

### Install Command
```
NvidiaSyncSetup.exe /S /norestart
```

### Uninstall Command
```
NvidiaSyncSetup.exe /S /norestart /uninstall
```

### Detection Rule
**Type**: Custom Script
**Script**: detect-nvidiasync.ps1

### Requirements
- Operating System Architecture: x64
- Minimum OS: Windows 10 1607
