<#
.SYNOPSIS
    Detection script for Google Drive installation.

.DESCRIPTION
    Checks whether Google Drive is installed and whether the installed version
    is at or above the minimum supported version.

    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant

.NOTES
    This script checks the uninstall registry entries for Google Drive.
#>

[CmdletBinding()]
Param(
    [version]$MinimumVersion = [version]'129.0.1.0'
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
$LogFile = $null
$LoggingEnabled = $false

try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $LogFile = Join-Path $LogFolder "GoogleDrive-detect.log"
    "Test" | Out-File -FilePath $LogFile -Append -ErrorAction Stop
    $LoggingEnabled = $true
} catch {
    $LoggingEnabled = $false
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if (-not $script:LoggingEnabled) {
        return
    }

    try {
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
        $logLine | Out-File -FilePath $script:LogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore logging errors
    }
}

function Test-VersionAtLeast {
    param(
        [string]$InstalledVersion,
        [version]$MinimumVersion
    )

    if ([string]::IsNullOrWhiteSpace($InstalledVersion)) {
        return $false
    }

    try {
        $parsedInstalled = [version]$InstalledVersion
        return $parsedInstalled -ge $MinimumVersion
    }
    catch {
        return $false
    }
}

try {
    Write-Log "=== Starting Google Drive detection ==="
    Write-Log "Minimum required version: $MinimumVersion"

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $matchingInstall = $null

    foreach ($regPath in $registryPaths) {
        Write-Log "Checking registry path: $regPath"

        $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -like "*Google Drive*" -and $_.DisplayVersion
            }

        if ($items) {
            foreach ($item in $items) {
                Write-Log "Found Google Drive entry: $($item.DisplayName)"
                Write-Log "DisplayVersion: $($item.DisplayVersion)"

                if (Test-VersionAtLeast -InstalledVersion $item.DisplayVersion -MinimumVersion $MinimumVersion) {
                    $matchingInstall = $item
                    break
                }
            }
        }

        if ($matchingInstall) {
            break
        }
    }

    if ($matchingInstall) {
        Write-Log "=== Detection complete: DETECTED ==="
        Write-Log "Google Drive version $($matchingInstall.DisplayVersion) is compliant."
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        Write-Log "No supported Google Drive version found at or above $MinimumVersion."
        exit 1
    }
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
