<#
.SYNOPSIS
    Detection script for NVIDIA Sync installation

.DESCRIPTION
    Checks if NVIDIA Sync is installed by checking the registry.
    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant

.NOTES
    TODO: Confirm the actual DisplayName NVIDIA Sync registers under and update
    $DisplayNameFilter below.
#>

[CmdletBinding()]
Param(
    [string]$DisplayNameFilter = "*NVIDIA Sync*"
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $LogFile = Join-Path $LogFolder "NvidiaSync-detect.log"
}
catch {
    # Fallback to temp if we can't write to Windows\Logs
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "NvidiaSync-detect.log"
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
    $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

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
    Write-Log "=== Starting NVIDIA Sync detection ==="

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $found = $false
    $version = $null

    foreach ($regPath in $registryPaths) {
        Write-Log "Checking registry path: $regPath"

        $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $DisplayNameFilter }

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

    if ($found) {
        Write-Log "=== Detection complete: DETECTED ==="
        Write-Log "NVIDIA Sync version $version is installed"
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        Write-Log "NVIDIA Sync is not installed"
        exit 1
    }
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
