# 1Password MSI Installer for Intune

This folder contains the scripts for deploying 1Password via Intune Win32 app deployment using the official MSI installer.

## Files

### Source Scripts
- **install-1password.ps1** - Downloads and installs 1Password MSI from the official download URL
- **detect-1password.ps1** - Detection script that checks the registry for 1Password installation
- **uninstall-1password.ps1** - Uninstalls 1Password by removing the MSI package

### Package
- **1Password.intunewin** - The packaged .intunewin file (generated using IntuneWinAppUtil.exe)

## MSI Download

The install script automatically downloads the latest 1Password MSI from:
```
https://c.1password.com/dist/1P/win8/1PasswordSetup-latest.msi
```

## 1Password CLI

For 1Password CLI, deploy it separately using the existing winget detection scripts:
- Use `installers\winget\detect-AgileBits.1Password.CLI.ps1`
- Configure as a dependency in Intune if needed

## Installation Details

- **Install Context**: System (runs as SYSTEM)
- **Install Behavior**: Silent (`/qn`)
- **Restart Behavior**: No restart forced (`/norestart`)
- **Logs**:
  - Script log: `C:\Windows\Logs\Software\1Password-install.log`
  - MSI log: `C:\Windows\Logs\Software\1Password-msi-install.log`

## Detection Method

The detection script checks the Windows registry for 1Password entries:
- `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`
- `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*`

Looks for DisplayName containing "1Password" (excluding CLI)

## Creating the .intunewin Package

Use the Microsoft Win32 Content Prep Tool:

```powershell
.\IntuneWinAppUtil.exe `
    -c "installers\1Password\source" `
    -s "install-1password.ps1" `
    -o "installers\1Password\package"
```

## Intune Configuration

### Install Command
```
powershell.exe -ExecutionPolicy Bypass -File install-1password.ps1
```

### Uninstall Command
```
powershell.exe -ExecutionPolicy Bypass -File uninstall-1password.ps1
```

### Detection Rule
**Type**: Custom Script
**Script**: detect-1password.ps1

### Requirements
- Operating System Architecture: x64
- Minimum OS: Windows 10 1607

## Notes

- The MSI is downloaded at install time, ensuring you always get the latest version
- Installation is silent and requires no user interaction
- Detection works in SYSTEM context (Intune detection always runs as SYSTEM)
- All actions are logged to `C:\Windows\Logs\Software\` for troubleshooting
