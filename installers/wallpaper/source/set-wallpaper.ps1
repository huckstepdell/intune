<#
.SYNOPSIS
    Set custom wallpaper for Intune deployment

.DESCRIPTION
    Copies all jpg and png wallpaper files from the script directory to
    C:\Windows\Web\Wallpaper so they can be referenced by the
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

    $wallpaperRoot = "C:\Windows\Web\Wallpaper"

    if (-not (Test-Path $wallpaperRoot)) {
        Write-Log "Creating wallpaper directory: $wallpaperRoot"
        New-Item -Path $wallpaperRoot -ItemType Directory -Force | Out-Null
    }

    $sourceFiles = Get-ChildItem -Path $PSScriptRoot -File | Where-Object { $_.Extension -in '.jpg', '.png', '.JPG', '.PNG' }

    if ($sourceFiles.Count -eq 0) {
        throw "No jpg or png files found in source directory: $PSScriptRoot"
    }

    Write-Log "Copying $($sourceFiles.Count) wallpaper file(s) to $wallpaperRoot"
    foreach ($file in $sourceFiles) {
        Write-Log "Copying: $($file.Name)"
        Copy-Item $file.FullName -Destination $wallpaperRoot -Force
    }

    Write-Log "Wallpaper files copied successfully"

    # --- Create registry entry for detection ---
    Write-Log "Creating registry entry for Intune detection"
    $regPath = "HKLM:\SOFTWARE\Intune\Wallpaper"

    if (-not (Test-Path $regPath)) {
        Write-Log "Creating registry path: $regPath"
        New-Item -Path $regPath -Force | Out-Null
    }

    $version = "26.08.24.2"
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