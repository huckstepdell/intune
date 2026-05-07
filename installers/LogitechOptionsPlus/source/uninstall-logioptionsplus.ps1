<#
.SYNOPSIS
    Uninstall Logitech Options+

.DESCRIPTION
    Uninstalls Logitech Options+ by finding and running its uninstaller.
    Logs to C:\Windows\Logs\Software\LogitechOptionsPlus-uninstall.log
#>

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "LogitechOptionsPlus-uninstall.log"

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
    Write-Log "=== Starting Logitech Options+ uninstallation ==="

    $uninstallerPath = Join-Path $env:ProgramFiles "LogiOptionsPlus\logioptionsplus_uninstaller.exe"

    if (Test-Path $uninstallerPath) {
        Write-Log "Found uninstaller: $uninstallerPath"
        
        $arguments = @("/quiet")
        Write-Log "Running: `"$uninstallerPath`" $($arguments -join ' ')"
        
        $process = Start-Process -FilePath $uninstallerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        $exitCode = $process.ExitCode
        
        Write-Log "Uninstallation completed with exit code: $exitCode"
        
        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Log "Uninstallation completed successfully"
        }
        else {
            Write-Log "Uninstallation failed with exit code: $exitCode" -Level Error
            throw "Uninstallation failed with exit code $exitCode"
        }
    }
    else {
        Write-Log "Uninstaller not found at $uninstallerPath." -Level Warning
        
        # Fallback to checking registry if default path fails
        Write-Log "Checking registry for Logitech Options+ uninstaller..."
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $uninstalled = $false
        foreach ($regPath in $registryPaths) {
            $app = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -match "Logi.*Options\+" } |
                   Select-Object -First 1

            if ($app -and $app.QuietUninstallString) {
                Write-Log "Found QuietUninstallString: $($app.QuietUninstallString)"
                
                $cmdArgs = "/c `"$($app.QuietUninstallString)`""
                Write-Log "Running: cmd.exe $cmdArgs"
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs -Wait -PassThru -WindowStyle Hidden
                
                Write-Log "Uninstallation completed with exit code: $($process.ExitCode)"
                $uninstalled = $true
                break
            }
            elseif ($app -and $app.UninstallString) {
                Write-Log "Found UninstallString: $($app.UninstallString)"
                
                $cmdArgs = "/c `"$($app.UninstallString)`""
                Write-Log "Running: cmd.exe $cmdArgs"
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs -Wait -PassThru -WindowStyle Hidden
                
                Write-Log "Uninstallation completed with exit code: $($process.ExitCode)"
                $uninstalled = $true
                break
            }
        }
        
        if (-not $uninstalled) {
            Write-Log "Logitech Options+ uninstaller could not be found. Assuming already uninstalled." -Level Warning
        }
    }

    Write-Log "=== Logitech Options+ uninstallation completed successfully ==="
    exit 0
}
catch {
    Write-Log "Uninstallation failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
