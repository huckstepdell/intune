<#
.SYNOPSIS
    Removes the default Python virtual environment for the current user

.DESCRIPTION
    Deletes $HOME\venvs\default. Leaves other venvs under $HOME\venvs untouched.

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
    $LogFile = Join-Path $LogFolder "PythonVenv-uninstall.log"
}
catch {
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "PythonVenv-uninstall.log"
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
    Write-Log "=== Starting Python venv removal ==="

    $venvPath = Join-Path $HOME "venvs\default"

    if (Test-Path $venvPath) {
        Write-Log "Removing venv at: $venvPath"
        Remove-Item -Path $venvPath -Recurse -Force
        Write-Log "=== Python venv removal completed successfully ==="
    }
    else {
        Write-Log "Venv not present, nothing to remove: $venvPath"
    }

    exit 0
}
catch {
    Write-Log "Uninstall failed: $($_.Exception.Message)" -Level Error
    exit 1
}
