<#
.SYNOPSIS
    Detection script for Tailscale MSI installation

.DESCRIPTION
    Tailscale auto-updates itself in the background, so the installed version quickly
    drifts past the version originally deployed via Intune. A strict MSI (ProductCode +
    exact version) detection rule will start reporting "not installed" as soon as
    Tailscale updates itself, even though the app is present and healthy.

    This script instead checks that Tailscale is installed and that its version is
    greater than or equal to $MinimumVersion, so auto-updates don't break detection.

    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant
#>

[CmdletBinding()]
Param(
    # The version originally packaged - installs at or above this version are compliant
    [string]$MinimumVersion = "1.102.2"
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $LogFile = Join-Path $LogFolder "Tailscale-detect.log"
}
catch {
    # Fallback to temp if we can't write to Windows\Logs
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "Tailscale-detect.log"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $logLevel = switch ($Level) {
        'Info'    { 1 }
        'Warning' { 2 }
        'Error'   { 3 }
        default   { 1 }
    }

    $component = Split-Path -Leaf $MyInvocation.ScriptName
    $time = Get-Date -Format "HH:mm:ss.fff"
    $date = Get-Date -Format "MM-dd-yyyy"
    $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
    $timeZoneString = "{0:+000;-000}" -f $timeZoneBias

    $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

    try {
        $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction Stop
    }
    catch {
        # Silently fail if we can't write logs (will work in Intune as SYSTEM)
    }
}

function Test-VersionAtLeast {
    param(
        [string]$InstalledVersion,
        [string]$MinimumVersion
    )

    # Strip any pre-release/build suffix (e.g. "1.102.2-t1234abcdef" -> "1.102.2")
    $installedBase = ($InstalledVersion -split '-')[0]
    $minimumBase    = ($MinimumVersion  -split '-')[0]

    try {
        return ([System.Version]$installedBase) -ge ([System.Version]$minimumBase)
    }
    catch {
        Write-Log "Could not parse versions for comparison ('$InstalledVersion' vs '$MinimumVersion')" -Level Warning
        return $false
    }
}

# --- Main logic ---
try {
    Write-Log "=== Starting Tailscale detection (minimum version: $MinimumVersion) ==="

    $found = $false
    $foundVersion = $null

    # 1) Check registry uninstall keys (Tailscale's MSI is 64-bit only, but check both hives)
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($regPath in $registryPaths) {
        Write-Log "Checking registry path: $regPath"

        $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq "Tailscale" }

        foreach ($app in $apps) {
            Write-Log "Found registry entry: $($app.DisplayName) version $($app.DisplayVersion)"
            if (Test-VersionAtLeast -InstalledVersion $app.DisplayVersion -MinimumVersion $MinimumVersion) {
                $found = $true
                $foundVersion = $app.DisplayVersion
            }
        }
    }

    # 2) Fallback: check the installed binary directly, in case the registry entry is
    #    stale/missing right after an auto-update swaps files but hasn't finished registering
    if (-not $found) {
        $exePath = "C:\Program Files\Tailscale\tailscale.exe"
        if (Test-Path $exePath) {
            $fileVersion = (Get-Item $exePath).VersionInfo.ProductVersion
            Write-Log "Found tailscale.exe on disk, ProductVersion: $fileVersion"
            if (Test-VersionAtLeast -InstalledVersion $fileVersion -MinimumVersion $MinimumVersion) {
                $found = $true
                $foundVersion = $fileVersion
            }
        }
        else {
            Write-Log "tailscale.exe not found at: $exePath"
        }
    }

    if ($found) {
        Write-Log "=== Detection complete: DETECTED ==="
        Write-Log "Tailscale version $foundVersion is installed (>= $MinimumVersion)"
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        Write-Log "Tailscale is not installed, or installed version is below $MinimumVersion"
        exit 1
    }
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
