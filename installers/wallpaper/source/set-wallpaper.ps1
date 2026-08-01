<#
.SYNOPSIS
    Set custom wallpaper for Intune deployment

.DESCRIPTION
    Replaces Windows default wallpaper with custom images.
    Creates a registry entry for Intune detection.

.NOTES
    Registry detection: HKLM:\SOFTWARE\Intune\Wallpaper
#>

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "Wallpaper-install.log"

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
    Write-Log "=== Starting wallpaper installation ==="

    Write-Log "Taking ownership of default wallpaper files"
    takeown /f c:\windows\WEB\wallpaper\Windows\img0.jpg
    takeown /f C:\Windows\Web\4K\Wallpaper\Windows\*.*

    Write-Log "Granting System permissions"
    icacls c:\windows\WEB\wallpaper\Windows\img0.jpg /Grant 'System:(F)'
    icacls C:\Windows\Web\4K\Wallpaper\Windows\*.* /Grant 'System:(F)'

    Write-Log "Removing default wallpaper files"
    Remove-Item c:\windows\WEB\wallpaper\Windows\img0.jpg
    Remove-Item C:\Windows\Web\4K\Wallpaper\Windows\*.*

    Write-Log "Copying custom wallpaper from script directory"
    Copy-Item "$PSScriptRoot\img0.jpg" "c:\windows\WEB\wallpaper\Windows\img0.jpg" -Force
    Write-Log "Wallpaper copied successfully"

    # --- Create registry entry for detection ---
    Write-Log "Creating registry entry for Intune detection"
    $regPath = "HKLM:\SOFTWARE\Intune\Wallpaper"

    if (-not (Test-Path $regPath)) {
        Write-Log "Creating registry path: $regPath"
        New-Item -Path $regPath -Force | Out-Null
    }

    $version = "1.0.0"
    $installedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Log "Setting registry values: Version=$version, InstalledDate=$installedDate"
    New-ItemProperty -Path $regPath -Name "Version" -Value $version -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "InstalledDate" -Value $installedDate -PropertyType String -Force | Out-Null

    Write-Log "=== Wallpaper installation completed successfully ==="
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}