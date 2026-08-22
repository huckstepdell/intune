<#
.SYNOPSIS
    Detection script for the default Python virtual environment

.DESCRIPTION
    Checks for $HOME\venvs\default\Scripts\python.exe and pyvenv.cfg.
    Exit codes:
      0 -> Venv detected and compliant
      1 -> Venv not detected / non-compliant

.NOTES
    This app must be deployed as a User-context Win32 app in Intune (not System),
    since $HOME needs to resolve to the logged-on user's profile.
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = Join-Path $env:LOCALAPPDATA "Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $LogFile = Join-Path $LogFolder "PythonVenv-detect.log"
}
catch {
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "PythonVenv-detect.log"
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
        # Silently ignore logging errors
    }
}

# --- Main logic ---
try {
    Write-Log "=== Starting Python venv detection ==="

    $venvPath = Join-Path $HOME "venvs\default"
    $venvPython = Join-Path $venvPath "Scripts\python.exe"
    $venvCfg = Join-Path $venvPath "pyvenv.cfg"

    Write-Log "Checking for: $venvPython"
    Write-Log "Checking for: $venvCfg"

    if ((Test-Path $venvPython) -and (Test-Path $venvCfg)) {
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
