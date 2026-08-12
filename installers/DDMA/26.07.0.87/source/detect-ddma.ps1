<#
.SYNOPSIS
    Detection script for Dell Device Management Agent (DDMA)

.DESCRIPTION
    Checks the uninstall registry to see if Dell Device Management Agent is installed
    and whether it is at least version 26.07.0.87. This avoids depending on a hard-coded GUID.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\detect-ddma.ps1

.NOTES
    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$requiredVersion = [version]'26.07.0.87'
$logFolder = 'C:\Windows\Logs\Software'

try {
    if (-not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
    $logFile = Join-Path $logFolder 'ddma-detect.log'
}
catch {
    $logFolder = $env:TEMP
    $logFile = Join-Path $logFolder 'ddma-detect.log'
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info','Warning','Error')]
        [string]$Level = 'Info'
    )

    $logLevel = switch ($Level) {
        'Info'    { 1 }
        'Warning' { 2 }
        'Error'   { 3 }
        default   { 1 }
    }

    $component = Split-Path -Leaf $MyInvocation.ScriptName
    $time = Get-Date -Format 'HH:mm:ss.fff'
    $date = Get-Date -Format 'MM-dd-yyyy'
    $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
    $timeZoneString = '{0:+000;-000}' -f $timeZoneBias
    $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

    try {
        $logLine | Out-File -FilePath $logFile -Append -Encoding utf8 -ErrorAction Stop
    }
    catch {
        # Intune runs as SYSTEM; this is best-effort only.
    }
}

try {
    Write-Log "=== Starting Dell Device Management Agent detection ==="
    Write-Log "Required version: $requiredVersion"

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($path in $paths) {
        Write-Log "Checking registry path: $path"

        try {
            $items = Get-ChildItem -Path $path -ErrorAction Stop
        }
        catch {
            Write-Log "Path not found or inaccessible: $path" -Level Warning
            continue
        }

        foreach ($item in $items) {
            try {
                $props = Get-ItemProperty -Path $item.PSPath -ErrorAction Stop
            }
            catch {
                continue
            }

            $displayName = [string]$props.DisplayName
            $displayVersion = [string]$props.DisplayVersion

            if (($displayName -match 'Dell Device Management Agent') -or ($displayName -match 'DDMA') -or ($displayName -match 'Dell.*Management.*Agent')) {
                if ($displayVersion) {
                    Write-Log "Found product: $displayName"
                    Write-Log "DisplayVersion: $displayVersion"

                    try {
                        $installedVersion = [version]$displayVersion
                        if ($installedVersion -ge $requiredVersion) {
                            Write-Log "Detected compliant version: $installedVersion"
                            Write-Output "Detected"
                            exit 0
                        }
                        else {
                            Write-Log "Detected older version: $installedVersion; required >= $requiredVersion" -Level Warning
                        }
                    }
                    catch {
                        Write-Log "Unable to parse version $displayVersion as [version]" -Level Warning
                    }
                }
            }
        }
    }

    Write-Log "Dell Device Management Agent not detected or not compliant" -Level Warning
    exit 1
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
