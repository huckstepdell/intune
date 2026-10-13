<#
.SYNOPSIS
    Detection script for Action1 MSI installation

.DESCRIPTION
    Checks if Action1 is installed via MSI by checking registry.
    Exit codes:
      0 -> App detected and compliant (version >= 6.0.664.1)
      1 -> App not detected / non-compliant

.NOTES
    Checks both 32-bit and 64-bit registry paths for Action1.
    Version: 6.0.664.1
    Copyright (C) 2021 Action1 Corporation
    Self-updating: Returns compliant if version >= 6.0.664.1
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $LogFile = Join-Path $LogFolder "Action1-detect.log"
}
catch {
    # Fallback to temp if we can't write to Windows\Logs
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "Action1-detect.log"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    # Map log levels to CMTrace format: 1=Info, 2=Warning, 3=Error
    $logLevel = switch ($Level) {
        'Info'    { 1 }
        'Warning' { 2 }
        'Error'   { 3 }
        default   { 1 }
    }

    # Get caller info
    $component = Split-Path -Leaf $MyInvocation.ScriptName

    # Build timestamp in CMTrace format
    $time = Get-Date -Format "HH:mm:ss.fff"
    $date = Get-Date -Format "MM-dd-yyyy"
    $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
    $timeZoneString = "{0:+000;-000}" -f $timeZoneBias

    # Build CMTrace/OneTrace format log line
    $logLine = "<![LOG[$Message]LOG]!><time name=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

    # Write to log file
    try {
        $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction Stop
    }
    catch {
        # Silently fail if we can't write logs (will work in Intune as SYSTEM)
    }
}

# --- Main logic ---
try {
    Write-Log "=== Starting Action1 detection ==="

    # Target version for compliance check (self-updating: >= this version is OK)
    $targetVersion = [System.Version]"6.0.664.1"
    Write-Log "Target version for compliance: $($targetVersion.ToString())"

    # Check registry for Action1 installation
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $found = $false
    $version = $null

    foreach ($regPath in $registryPaths) {
        Write-Log "Checking registry path: $regPath"

        $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*Action1*" }

        if ($apps) {
            foreach ($app in $apps) {
                Write-Log "Found: $($app.DisplayName)"
                Write-Log "  Version: $($app.DisplayVersion)"
                Write-Log "  Publisher: $($app.Publisher)"
                Write-Log "  Install Location: $($app.InstallLocation)"

                $found = $true
                $version = $app.DisplayVersion
            }
        }
    }

    if ($found -and $version) {
        # Parse the installed version
        $installedVersion = $null
        if ([System.Version]::TryParse($version, [ref]$installedVersion)) {
            Write-Log "Parsed installed version: $($installedVersion.ToString())"
            
            # Compare versions (self-updating: >= target is compliant)
            $comparison = $installedVersion.CompareTo($targetVersion)
            
            if ($comparison -ge 0) {
                Write-Log "=== Detection complete: DETECTED (COMPLIANT) ==="
                Write-Log "Action1 version $($installedVersion.ToString()) >= $($targetVersion.ToString()) is installed"
                Write-Output "Detected"
                exit 0
            }
            else {
                Write-Log "=== Detection complete: NOT DETECTED (OUTDATED) ===" -Level Warning
                Write-Log "Action1 version $($installedVersion.ToString()) < $($targetVersion.ToString()) requires update"
                exit 1
            }
        }
        else {
            Write-Log "=== Detection complete: NOT DETECTED (INVALID VERSION) ===" -Level Warning
            Write-Log "Could not parse version: $version"
            exit 1
        }
    }
    else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        Write-Log "Action1 is not installed"
        exit 1
    }
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
