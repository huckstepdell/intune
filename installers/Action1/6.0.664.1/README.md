# Action1

## Version
6.0.664.1

## Copyright
Copyright (C) 2021 Action1 Corporation

## Description
Action1 Endpoint Management Platform

## Installation
Run `install-action1.ps1` to install the Action1 agent via MSI.

## Detection
Run `detect-action1.ps1` to check if Action1 is installed.

## Uninstallation
To uninstall Action1, run:
```
msiexec /x {PRODUCT-CODE} /qn /norestart
```

Replace `{PRODUCT-CODE}` with the actual MSI product code for Action1.

## Notes
- This installer uses MSI format
- Requires administrator privileges
- May require reboot to complete installation
