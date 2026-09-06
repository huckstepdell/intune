<#>
.SYNOPSIS
    Enable or Disable RDP (Remote Desktop Protocol) for Intune deployment

.DESCRIPTION
    Enables or disables RDP by modifying registry settings.
    Logs to C:\Windows\Logs\Software\RDP-setup.log

.PARAMETER Enable
    Enable RDP (default behavior if no parameter specified)

.PARAMETER Disable
    Disable RDP

.PARAMETER RequireNLA
    Require Network Level Authentication (default: true)

.EXAMPLE
    .\install-rdp.ps1         # Enable RDP
    .\install-rdp.ps1 -Enable # Enable RDP (explicit)
    .\install-rdp.ps1 -Disable # Disable RDP

.NOTES
    Registry paths modified:
    - HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections
    - HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\UserAuthentication
    - HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\NlaAuthentication
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [Switch]$Enable,

    [Parameter(Mandatory = $false)]
    [Switch]$Disable,

    [Parameter(Mandatory = $false)]
    [ValidateSet($true, $false)]
    [bool]$RequireNLA = $true
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
} catch {
    Write-Host "Warning: Could not create log folder: $LogFolder"
    $LogFolder = "$env:TEMP"
}

$LogFile = Join-Path $LogFolder "RDP-setup.log"

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
    $logLine = '<![LOG[{0}]LOG]!><time name="{1}{2}" date="{3}" component="{4}" context="" type="{5}" thread="{6}" file="{4}">' -f $Message, $time, $timeZoneString, $date, $component, $logLevel, $PID

    # Write to log file
    $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# --- Main logic ---
try {
    # Determine if we're enabling or disabling
    $isDisable = $Disable.IsPresent

    if ($isDisable) {
        Write-Log "=== Starting RDP disablement ==="
    } else {
        Write-Log "=== Starting RDP enablement ==="
    }

    # Registry path for Terminal Server
    $terminalServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    $rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

    # Check if registry path exists
    if (-not (Test-Path $terminalServerPath)) {
        Write-Log "Terminal Server registry path not found: $terminalServerPath" -Level Error
        throw "Terminal Server registry path not found"
    }

    Write-Log "Terminal Server registry path found: $terminalServerPath"

    if ($isDisable) {
        # Disable RDP (fDenyTSConnections = 1 means RDP is disabled)
        Write-Log "Disabling RDP connections..."
        Set-ItemProperty -Path $terminalServerPath -Name "fDenyTSConnections" -Value 1 -Type DWord -ErrorAction Stop
        Write-Log "Set fDenyTSConnections = 1 (RDP disabled)"
    }
    else {
        # Enable RDP (fDenyTSConnections = 0 means RDP is enabled)
        Write-Log "Enabling RDP connections..."
        Set-ItemProperty -Path $terminalServerPath -Name "fDenyTSConnections" -Value 0 -Type DWord -ErrorAction Stop
        Write-Log "Set fDenyTSConnections = 0 (RDP enabled)"

        # Configure RDP security settings (optional but recommended)
        # NlaAuthentication = 1 - Requires NLA (Network Level Authentication)
        # UserAuthentication = 1 - Requires NLA for remote connections
        if ($RequireNLA) {
            Write-Log "Configuring RDP security settings (NLA required)..."
            if (Test-Path $rdpPath) {
                Set-ItemProperty -Path $rdpPath -Name "UserAuthentication" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path $rdpPath -Name "NlaAuthentication" -Value 1 -Type DWord -ErrorAction Stop
                Write-Log "Set UserAuthentication = 1 and NlaAuthentication = 1 (NLA required)"
            } else {
                Write-Log "RDP-Tcp registry path not found, skipping NLA configuration" -Level Warning
            }
        }
    }

    # Verify RDP status
    $rdpEnabled = (Get-ItemProperty -Path $terminalServerPath -Name "fDenyTSConnections" -ErrorAction Stop).fDenyTSConnections

    if ($isDisable) {
        if ($rdpEnabled -eq 1) {
            Write-Log "RDP is now disabled (fDenyTSConnections = 1)"
        } else {
            Write-Log "Warning: RDP may not be properly disabled (fDenyTSConnections = $rdpEnabled)" -Level Warning
        }
        Write-Log "=== RDP disablement completed ==="
        exit 0
    }
    else {
        if ($rdpEnabled -eq 0) {
            Write-Log "RDP is now enabled (fDenyTSConnections = 0)"
        } else {
            Write-Log "Warning: RDP may not be properly enabled (fDenyTSConnections = $rdpEnabled)" -Level Warning
        }
        Write-Log "=== RDP enablement completed successfully ==="
        exit 0
    }
}
catch {
    Write-Log "RDP setup failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
