# RDP (Remote Desktop Protocol) Setup for Intune

## Overview
This folder contains PowerShell scripts to enable/disable RDP on Windows devices via Intune.

## Scripts

| File | Description |
|------|-------------|
| `install-rdp.ps1` | Main script to enable/disable RDP (supports -Enable and -Disable switches) |
| `detect-rdp.ps1` | Detection script to check if RDP is enabled |

## Features
- Registry-based RDP enable/disable using `fDenyTSConnections` (0=enabled, 1=disabled)
- NLA (Network Level Authentication) configuration
- CMTrace-compatible logging to `C:\Windows\Logs\Software\`

## Usage

### Enable RDP
```powershell
.\install-rdp.ps1
# or explicitly:
.\install-rdp.ps1 -Enable
```

### Disable RDP
```powershell
.\install-rdp.ps1 -Disable
```

### With Options
```powershell
# Disable NLA requirement (not recommended for production)
.\install-rdp.ps1 -RequireNLA:$false
```

## Intune Deployment Commands

### Enable RDP
**Install command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File install-rdp.ps1
```

**Install with NLA disabled:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File install-rdp.ps1 -RequireNLA:$false
```

### Disable RDP
**Uninstall command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File install-rdp.ps1 -Disable
```

## Detection
```powershell
# Check if RDP is enabled
.\detect-rdp.ps1

# Check if RDP is enabled AND NLA is required
.\detect-rdp.ps1 -RequireNLA
```

Exit codes:
- `0` = RDP is enabled (detection passed)
- `1` = RDP is disabled (detection failed)

## Registry Settings Modified
- `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections` (0=enabled, 1=disabled)
- `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\UserAuthentication` (NLA)
- `HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\NlaAuthentication` (NLA)

## Intune Deployment
1. Upload `install-rdp.ps1` as a PowerShell script in Microsoft Endpoint Manager
2. Set **Run this script using the logged-on credentials** = No
3. Set **Enable 32-bit scripts on 64-bit architecture** = Yes (if needed)
4. Use `detect-rdp.ps1` as the detection rule