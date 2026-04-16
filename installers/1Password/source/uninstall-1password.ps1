<#
.SYNOPSIS
    Uninstall 1Password MSI

.DESCRIPTION
    Uninstalls 1Password by finding and removing the MSI installation.
    Logs to C:\Windows\Logs\Software\1Password-uninstall.log

.NOTES
    Searches registry for the product code and uninstalls via msiexec.
    For 1Password CLI uninstall, use the separate winget uninstall script.
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "1Password-uninstall.log"

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
try {uninstallation ==="

    # Check registry for 1Password installation
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $productCode = $null

    foreach ($regPath in $registryPaths) {
        Write-Log "Checking registry path: $regPath"

        $app = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -like "*1Password*" -and $_.DisplayName -notlike "*CLI*" } |
               Select-Object -First 1

        if ($app) {
            Write-Log "Found: $($app.DisplayName)"
            Write-Log "  Version: $($app.DisplayVersion)"

            # Extract product code from UninstallString or PSChildName
            if ($app.PSChildName -match '\{[A-F0-9-]+\}') {
                $productCode = $matches[0]
                Write-Log "  Product Code: $productCode"
                break
            }
            elseif ($app.UninstallString -match '\{[A-F0-9-]+\}') {
                $productCode = $matches[0]
                Write-Log "  Product Code: $productCode"
                break
            }
        }
    }

    if (-not $productCode) {
        Write-Log "1Password is not installed or product code not found" -Level Warning
        Write-Log "Nothing to uninstall"
        exit 0
    }

    # Uninstall using msiexec
    Write-Log "Starting MSI uninstallation..."
    $msiLogPath = Join-Path $LogFolder "1Password-msi-uninstall.log"

    $arguments = @(
        "/x",
        $productCode,
        "/qn",
        "/norestart",
        "/L*v",
        "`"$msiLogPath`""
    )

    Write-Log "Running: msiexec.exe $($arguments -join ' ')"

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode

    Write-Log "MSI uninstallation completed with exit code: $exitCode"

    # MSI exit codes
    # 0 = Success
    # 3010 = Success, reboot required
    # 1605 = Product not found (already uninstalled)
    if ($exitCode -eq 0) {
        Write-Log "Uninstallation completed successfully"
    }
    elseif ($exitCode -eq 3010) {
        Write-Log "Uninstallation completed successfully (reboot required)" -Level Warning
    }
    elseif ($exitCode -eq 1605) {
        Write-Log "Product not found (may already be uninstalled)" -Level Warning
    }
    else {
        Write-Log "Uninstallation failed with exit code: $exitCode" -Level Error
        Write-Log "Check MSI log for details: $msiLogPath" -Level Error
        throw "MSI uninstallation failed with exit code $exitCode"
    }

    Write-Log "=== 1Password uninstallation completed successfully ==="
    exit 0   exit 0
    }
}
catch {
    Write-Log "Uninstallation failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
