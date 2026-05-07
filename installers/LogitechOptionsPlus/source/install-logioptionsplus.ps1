<#
.SYNOPSIS
    Downloads and installs the latest Logitech Options+ online installer silently.
.DESCRIPTION
    This script downloads the online installer (~43MB) directly from Logitech's servers
    and performs a silent installation with enterprise-friendly defaults (telemetry,
    SSO, and updates disabled). The online installer downloads additional components
    during installation.
    Logs to C:\Windows\Logs\Software\LogitechOptionsPlus-install.log
#>
[CmdletBinding()]
param()

# Start transcript early to capture everything
$TranscriptPath = Join-Path $env:TEMP "LogitechOptionsPlus-install-transcript.log"
Start-Transcript -Path $TranscriptPath -Force -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path $LogFolder "LogitechOptionsPlus-install.log"

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
        # Fallback to console if file write fails
        Write-Warning "Failed to write to log file: $_"
    }
}

# Direct link for the online installer (much smaller - ~43MB vs 1.2GB offline)
$downloadUrl = "https://download01.logi.com/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer.exe"
$installerPath = Join-Path -Path $env:TEMP -ChildPath "logioptionsplus_installer.exe"

try {
    Write-Log "=== Starting Logitech Options+ installation ==="
    Write-Log "Download URL: $downloadUrl"
    Write-Log "Installer path: $installerPath"

    Write-Log "Downloading Logitech Options+ offline installer..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    if (Test-Path $installerPath) {
        $fileSize = (Get-Item $installerPath).Length / 1MB
        Write-Log "Download completed. File size: $([math]::Round($fileSize, 2)) MB"
    }
    else {
        Write-Log "Download failed - file not found at $installerPath" -Level Error
        throw "Download failed"
    }

    Write-Log "Installing Logitech Options+ silently..."
    # Silent install parameters.
    # Optional flags available: /analytics no /update no /sso no /flow no
    $installArgs = @("/quiet", "/analytics", "no", "/update", "no", "/sso", "no", "/flow", "no")
    Write-Log "Install arguments: $($installArgs -join ' ')"

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode

    Write-Log "Installation process completed with exit code: $exitCode"

    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        $message = if ($exitCode -eq 3010) {
            "Logitech Options+ installed successfully. Reboot required. Exit code: $exitCode"
        } else {
            "Logitech Options+ installed successfully. Exit code: $exitCode"
        }
        Write-Log $message
        exit 0
    }
    else {
        Write-Log "Installation failed with exit code: $exitCode" -Level Error
        exit $exitCode
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $errorDetails = $_ | Out-String

    Write-Log "An error occurred: $errorMessage" -Level Error
    Write-Log "Full error details: $errorDetails" -Level Error

    if ($_.ScriptStackTrace) {
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    }

    # Also output to console for Intune logs
    Write-Error "Installation failed: $errorMessage"

    Stop-Transcript -ErrorAction SilentlyContinue
    exit 1
}
finally {
    if (Test-Path $installerPath) {
        Write-Log "Cleaning up installer file..."
        Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $installerPath)) {
            Write-Log "Installer file removed successfully"
        }
    }
    Write-Log "=== Logitech Options+ installation script completed ==="
    Stop-Transcript -ErrorAction SilentlyContinue
}
