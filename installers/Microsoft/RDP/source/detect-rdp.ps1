<#>
.SYNOPSIS
    Detect RDP (Remote Desktop Protocol) status for Intune compliance

.DESCRIPTION
    Checks if RDP is enabled by verifying the registry setting
    HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections
    Returns 0 if RDP is enabled (value = 0), 1 if disabled (value = 1)

.PARAMETER RequireNLA
    Also check that NLA is required (default: false)

.EXAMPLE
    .\detect-rdp.ps1         # Check if RDP is enabled
    .\detect-rdp.ps1 -RequireNLA # Check if RDP is enabled and NLA is required

.NOTES
    Registry path checked:
    - HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [switch]$RequireNLA
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder -ErrorAction Stop)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
} catch {
    Write-Host "Warning: Could not create log folder: $LogFolder. Falling back to TEMP."
    $LogFolder = $env:TEMP
}

$LogFile = Join-Path $LogFolder "detect-rdp.log"

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
    $logLine = '<![LOG[{0}]LOG]!><time name="{1}{2}" date="{3}" component="{4}" context="" type="{5}" thread="{6}" file="{4}">' -f $Message, $time, $timeZoneString, $date, $component, $logLevel, $PID
    try {
        $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction Stop
    } catch {
        Write-Host "Warning: Could not write RDP detection log: $($_.Exception.Message)"
    }
}

# --- Main logic ---
try {
    Write-Log "=== Starting RDP detection ==="

    # Registry path for Terminal Server
    $terminalServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"

    # Check if registry path exists
    if (-not (Test-Path $terminalServerPath)) {
        Write-Log "Terminal Server registry path not found: $terminalServerPath" -Level Error
        Write-Log "RDP is NOT enabled (registry path not found)"
        exit 1
    }

    Write-Log "Terminal Server registry path found: $terminalServerPath"

    # Get fDenyTSConnections value
    $fDenyTSConnections = (Get-ItemProperty -Path $terminalServerPath -Name "fDenyTSConnections" -ErrorAction Stop).fDenyTSConnections

    Write-Log "fDenyTSConnections = $fDenyTSConnections (0=enabled, 1=disabled)"

    if ($fDenyTSConnections -eq 0) {
        Write-Log "RDP is enabled"
        Write-Output "RDP is enabled"
    }
    elseif ($fDenyTSConnections -eq 1) {
        Write-Log "RDP is disabled"
        Write-Log "=== RDP detection completed (not enabled) ==="
        exit 1
    }
    else {
        Write-Log "Warning: fDenyTSConnections has unexpected value: $fDenyTSConnections" -Level Warning
        Write-Log "=== RDP detection completed (not enabled) ==="
        exit 1
    }

    # Check NLA if requested
    if ($RequireNLA) {
        Write-Log "Checking NLA configuration..."
        $rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

        if (-not (Test-Path $rdpPath)) {
            Write-Log "RDP-Tcp registry path not found, cannot verify NLA" -Level Warning
        }
        else {
            $userAuth = (Get-ItemProperty -Path $rdpPath -Name "UserAuthentication" -ErrorAction SilentlyContinue).UserAuthentication
            $nlaAuth = (Get-ItemProperty -Path $rdpPath -Name "NlaAuthentication" -ErrorAction SilentlyContinue).NlaAuthentication

            Write-Log "UserAuthentication = $userAuth, NlaAuthentication = $nlaAuth"

            if ($userAuth -eq 1 -and $nlaAuth -eq 1) {
                Write-Log "NLA is required"
            }
            else {
                Write-Log "NLA is not configured properly" -Level Warning
            }
        }
    }

    Write-Log "=== RDP detection completed (enabled) ==="
    exit 0
}
catch {
    Write-Log "RDP detection failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
