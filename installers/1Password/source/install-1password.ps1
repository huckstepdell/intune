<#
.SYNOPSIS
    Install 1Password MSI for Intune Win32 deployment

.DESCRIPTION
    Downloads and installs 1Password from the official MSI installer.
    Logs to C:\Windows\Logs\Software\1Password-install.log

.NOTES
    MSI download URL: https://c.1password.com/dist/1P/win8/1PasswordSetup-latest.msi
    For 1Password CLI, deploy separately via winget as a dependency.
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "1Password-install.log"

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
    Write-Log "=== Starting 1Password installation ==="

    # Download URL for latest 1Password MSI
    $downloadUrl = "https://c.1password.com/dist/1P/win8/1PasswordSetup-latest.msi"
    $tempDir = Join-Path $env:TEMP "1Password-Install"
    $msiPath = Join-Path $tempDir "1PasswordSetup.msi"

    # Create temp directory
    if (-not (Test-Path $tempDir)) {
        Write-Log "Creating temp directory: $tempDir"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }

    # Download MSI
    Write-Log "Downloading 1Password MSI from: $downloadUrl"
    Write-Log "Download destination: $msiPath"

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -UseBasicParsing
        Write-Log "Download completed successfully"
    }
    catch {
        Write-Log "Failed to download MSI: $($_.Exception.Message)" -Level Error
        throw
    }

    # Verify file exists
    if (-not (Test-Path $msiPath)) {
        Write-Log "MSI file not found after download: $msiPath" -Level Error
        throw "MSI download failed"
    }

    $fileSize = (Get-Item $msiPath).Length
    Write-Log "Downloaded MSI size: $fileSize bytes"

    # Install MSI
    Write-Log "Starting MSI installation..."
    $msiLogPath = Join-Path $LogFolder "1Password-msi-install.log"

    $arguments = @(
        "/i",
        "`"$msiPath`"",
        "/qn",
        "/norestart",
        "/L*v",
        "`"$msiLogPath`""
    )

    Write-Log "Running: msiexec.exe $($arguments -join ' ')"

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode

    Write-Log "MSI installation completed with exit code: $exitCode"

    # MSI exit codes
    # 0 = Success
    # 3010 = Success, reboot required
    # 1641 = Success, installer initiated reboot
    if ($exitCode -eq 0) {
        Write-Log "Installation completed successfully"
    }
    elseif ($exitCode -eq 3010 -or $exitCode -eq 1641) {
        Write-Log "Installation completed successfully (reboot required/initiated)" -Level Warning
    }
    else {
        Write-Log "Installation failed with exit code: $exitCode" -Level Error
        Write-Log "Check MSI log for details: $msiLogPath" -Level Error
        throw "MSI installation failed with exit code $exitCode"
    }

    # Cleanup
    Write-Log "Cleaning up temporary files..."
    if (Test-Path $msiPath) {
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        Write-Log "Removed: $msiPath"
    }

    Write-Log "=== 1Password installation completed successfully ==="
    exit 0
}
catch {
    Write-Log "Installation failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
