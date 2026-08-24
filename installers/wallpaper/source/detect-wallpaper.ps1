<#
.SYNOPSIS
    Detection script for custom wallpaper installation

.DESCRIPTION
    Checks if custom wallpaper is installed via registry check.
    Exit codes:
      0 -> Wallpaper detected and compliant
      1 -> Wallpaper not detected / non-compliant

.NOTES
    Registry detection: HKLM:\SOFTWARE\Intune\Wallpaper
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
    $LogFile = Join-Path $LogFolder "Wallpaper-detect.log"
}
catch {
    # Fallback to temp if we can't write to Windows\Logs
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "Wallpaper-detect.log"
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
    $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# --- Main logic ---
try {
    Write-Log "=== Starting wallpaper detection ==="

    $regCandidates = @(
        "HKLM:\SOFTWARE\WOW6432Node\Intune\Wallpaper",
        "HKLM:\SOFTWARE\Intune\Wallpaper"
    )

    $regPath = $regCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $regPath) {
        Write-Log "Registry path not found in either 64-bit or WOW6432Node hive" -Level Warning
        Write-Log "Wallpaper not detected. Returning non-compliant (exit 1)."
        exit 1
    }

    Write-Log "Registry path exists: $regPath"

    $requiredVersion = "26.08.24.2"

    # Check for Version property
    try {
        $version = Get-ItemProperty -Path $regPath -Name "Version" -ErrorAction Stop
        Write-Log "Found Version: $($version.Version)"

        if ($version.Version -ne $requiredVersion) {
            Write-Log "Version mismatch: found $($version.Version), required $requiredVersion" -Level Warning
            Write-Log "Wallpaper not detected. Returning non-compliant (exit 1)."
            exit 1
        }

        Write-Log "Wallpaper detected. Returning compliant (exit 0)."
        Write-Output "Detected"
        exit 0
    }
    catch {
        Write-Log "Version property not found in registry" -Level Warning
        Write-Log "Wallpaper not detected. Returning non-compliant (exit 1)."
        exit 1
    }
}
catch {
    Write-Log "Unexpected error in detection: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
