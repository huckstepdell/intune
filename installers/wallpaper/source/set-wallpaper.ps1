<#
.SYNOPSIS
    Set custom wallpaper for Intune deployment

.DESCRIPTION
    Stages img0.jpg at C:\Windows\Web\Wallpaper\Windows so it can be referenced by the
    Desktop Wallpaper (User) branding/Administrative Templates policy in Intune.
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

    $wallpaperRoot = "C:\Windows\Web\Wallpaper\Windows"
    $img0Destination = Join-Path $wallpaperRoot "img0.jpg"
    $img0Source = Join-Path $PSScriptRoot "img0.jpg"

    if (-not (Test-Path $wallpaperRoot)) {
        Write-Log "Creating wallpaper directory: $wallpaperRoot"
        New-Item -Path $wallpaperRoot -ItemType Directory -Force | Out-Null
    }

    Write-Log "Taking ownership of default wallpaper file"
    if (Test-Path $img0Destination) {
        takeown /f $img0Destination | Out-Null
    }

    Write-Log "Granting System permissions"
    if (Test-Path $img0Destination) {
        icacls $img0Destination /Grant 'System:(F)' | Out-Null
    }

    Write-Log "Removing default wallpaper file"
    if (Test-Path $img0Destination) {
        Remove-Item $img0Destination -Force
    }

    Write-Log "Copying custom wallpaper from script directory"
    if (-not (Test-Path $img0Source)) {
        throw "Cannot find source wallpaper file: $img0Source"
    }

    Copy-Item $img0Source $img0Destination -Force

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