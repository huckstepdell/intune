<#
.SYNOPSIS
    Detection script for Steam installation.

.DESCRIPTION
    Checks whether any version of Steam is installed. Steam's installer is only a
    bootstrap and Steam updates itself after install, so we don't track a specific
    version here - presence of an install is sufficient.

    Exit codes:
      0 -> App detected
      1 -> App not detected
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
$LogFile = $null
$LoggingEnabled = $false

try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $LogFile = Join-Path $LogFolder "Steam-detect.log"
    "Test" | Out-File -FilePath $LogFile -Append -ErrorAction Stop
    $LoggingEnabled = $true
} catch {
    $LoggingEnabled = $false
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if (-not $script:LoggingEnabled) {
        return
    }

    try {
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
        $logLine | Out-File -FilePath $script:LogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore logging errors
    }
}

try {
    Write-Log "=== Starting Steam detection ==="

    $detected = $false

    # Check registry for Steam install path (covers both 32-bit and 64-bit registry views)
    $registryKeys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam"
    )

    foreach ($key in $registryKeys) {
        Write-Log "Checking registry key: $key"
        $regItem = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue

        if ($regItem -and $regItem.InstallPath) {
            $steamExe = Join-Path $regItem.InstallPath "steam.exe"
            Write-Log "Found InstallPath: $($regItem.InstallPath)"

            if (Test-Path $steamExe) {
                Write-Log "Found steam.exe at: $steamExe"
                $detected = $true
                break
            }
        }
    }

    # Fall back to uninstall registry entries if InstallPath check didn't find it
    if (-not $detected) {
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($path in $uninstallPaths) {
            $item = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "Steam" }

            if ($item) {
                Write-Log "Found Steam uninstall entry: $($item.DisplayName)"
                $detected = $true
                break
            }
        }
    }

    if ($detected) {
        Write-Log "=== Detection complete: DETECTED ==="
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        exit 1
    }
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
