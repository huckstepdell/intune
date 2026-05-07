<#
.SYNOPSIS
    Detection script for Logitech Options+ installation

.DESCRIPTION
    Checks if Logitech Options+ is installed by checking both file path and registry.
    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant
#>

[CmdletBinding()]
Param(
    # Optional: Set this to enforce a minimum required version.
    # If left blank, the script just verifies that the app is installed,
    # which is ideal for apps that auto-update to newer versions.
    [string]$MinimumVersion = ""
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $LogFile = Join-Path $LogFolder "LogitechOptionsPlus-detect.log"
}
catch {
    # Fallback to temp if we can't write to Windows\Logs
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "LogitechOptionsPlus-detect.log"
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
    Write-Log "=== Starting Logitech Options+ detection ==="
    $found = $false

    # Method 1: Check expected installation path
    $exePath = Join-Path $env:ProgramFiles "LogiOptionsPlus\logioptionsplus.exe"
    if (Test-Path $exePath) {
        Write-Log "Found main executable: $exePath"
        $version = (Get-Item $exePath).VersionInfo.ProductVersion
        Write-Log "  Version: $version"
        $found = $true
    }
    else {
        Write-Log "Executable not found at default path: $exePath"
        
        # Method 2: Check registry as fallback
        Write-Log "Checking registry as fallback..."
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($regPath in $registryPaths) {
            $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -match "Logi.*Options\+" }

            if ($apps) {
                foreach ($app in $apps) {
                    Write-Log "Found in registry: $($app.DisplayName)"
                    Write-Log "  Version: $($app.DisplayVersion)"
                    
                    $found = $true
                    $version = $app.DisplayVersion
                    break
                }
            }
            if ($found) { break }
        }
    }

    if ($found) {
        if ($MinimumVersion -and $version) {
            try {
                $installedVer = [System.Version]$version
                $reqVer = [System.Version]$MinimumVersion
                if ($installedVer -lt $reqVer) {
                    Write-Log "=== Detection complete: NOT DETECTED (Version too old) ===" -Level Warning
                    Write-Log "Installed version ($installedVer) is less than required minimum ($reqVer)"
                    exit 1
                }
            } catch {
                Write-Log "Could not parse version for comparison. Installed: $version, Minimum: $MinimumVersion" -Level Warning
            }
        }

        Write-Log "=== Detection complete: DETECTED ==="
        if ($version) { Write-Log "Logitech Options+ version $version is installed" }
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        Write-Log "Logitech Options+ is not installed"
        exit 1
    }
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
