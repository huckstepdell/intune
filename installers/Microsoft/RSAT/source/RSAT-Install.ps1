<#
.SYNOPSIS
Install or uninstall RSAT and related tools on Windows 10/11 using a JSON config.

.DESCRIPTION
- Default: installs RSAT capabilities and optional features from RsatConfig.json
- With -Uninstall: removes those capabilities and optional features

.CONFIG FORMAT (RsatConfig.json)
{
  "Capabilities": [
    "Rsat.ServerManager.Tools~~~~0.0.1.0",
    "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
    "Rsat.CertificateServices.Tools~~~~0.0.1.0",
    "Rsat.Dns.Tools~~~~0.0.1.0",
    "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
  ],
  "OptionalFeatures": [
    "IIS-WebServerManagementTools"
  ]
}

.NOTES
- Requires Windows 10 1809+ or Windows 11 Pro/Enterprise
- Intended to run as SYSTEM (e.g., via Intune)
#>

param(
    [switch]$Uninstall,
    [string]$ConfigPath = ".\RsatConfig.json"
)

$Mode = if ($Uninstall) { 'Uninstall' } else { 'Install' }
Write-Output "RSAT script starting in mode: $Mode"

# Resolve config path relative to script location if needed
if (-not (Test-Path $ConfigPath)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $ConfigPath = Join-Path $scriptDir "RsatConfig.json"
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

$capabilities     = @($config.Capabilities)
$optionalFeatures = @($config.OptionalFeatures)

if (-not $capabilities -and -not $optionalFeatures) {
    Write-Error "No Capabilities or OptionalFeatures defined in $ConfigPath"
    exit 1
}

$os = Get-CimInstance Win32_OperatingSystem
Write-Output "Detected OS version: $($os.Version), ProductType: $($os.ProductType)"

# 1 = Workstation (client). RSAT FoD is only for client OS.
if ($os.ProductType -ne 1) {
    Write-Warning "This appears to be a server OS. Script is intended for Windows 10/11 client. Continuing, but RSAT may not apply."
}

Write-Output "Capabilities: $($capabilities -join ', ')"
Write-Output "OptionalFeatures: $($optionalFeatures -join ', ')"

# --- Handle RSAT capabilities ---
foreach ($capName in $capabilities) {
    try {
        Write-Output "Processing capability ($Mode): $capName"

        $cap = Get-WindowsCapability -Online -Name $capName -ErrorAction SilentlyContinue

        if ($null -eq $cap) {
            Write-Warning "Capability not found on this OS: $capName"
            continue
        }

        if ($Mode -eq 'Install') {
            if ($cap.State -eq 'Installed') {
                Write-Output "Capability already installed: $capName"
            }
            else {
                Write-Output "Installing capability $capName..."
                Add-WindowsCapability -Online -Name $capName -ErrorAction Stop | Out-Null
                Write-Output "Successfully installed $capName."
            }
        }
        else { # Uninstall
            if ($cap.State -eq 'Installed') {
                Write-Output "Removing capability $capName..."
                Remove-WindowsCapability -Online -Name $capName -ErrorAction Stop | Out-Null
                Write-Output "Successfully removed $capName."
            }
            else {
                Write-Output "Capability already absent: $capName"
            }
        }
    }
    catch {
        Write-Warning "Failed to process capability $capName in mode $Mode. Error: $($_.Exception.Message)"
    }
}

# --- Handle optional Windows features (e.g., IIS Mgmt tools) ---
foreach ($featName in $optionalFeatures) {
    try {
        Write-Output "Processing optional feature ($Mode): $featName"

        $feat = Get-WindowsOptionalFeature -Online -FeatureName $featName -ErrorAction SilentlyContinue

        if ($null -eq $feat) {
            Write-Warning "Optional feature not found on this OS: $featName"
            continue
        }

        if ($Mode -eq 'Install') {
            if ($feat.State -eq 'Enabled') {
                Write-Output "Optional feature already enabled: $featName"
            }
            else {
                Write-Output "Enabling optional feature $featName..."
                Enable-WindowsOptionalFeature -Online -FeatureName $featName -All -NoRestart -ErrorAction Stop | Out-Null
                Write-Output "Successfully enabled $featName."
            }
        }
        else { # Uninstall
            if ($feat.State -eq 'Enabled') {
                Write-Output "Disabling optional feature $featName..."
                Disable-WindowsOptionalFeature -Online -FeatureName $featName -NoRestart -ErrorAction Stop | Out-Null
                Write-Output "Successfully disabled $featName."
            }
            else {
                Write-Output "Optional feature already disabled: $featName"
            }
        }
    }
    catch {
        Write-Warning "Failed to process optional feature $featName in mode $Mode. Error: $($_.Exception.Message)"
    }
}

Write-Output "RSAT / IIS tools $Mode operation completed."
exit 0