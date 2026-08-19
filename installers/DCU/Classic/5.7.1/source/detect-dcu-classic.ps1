<#
.SYNOPSIS
    Detection script for Dell Command | Update Classic

.DESCRIPTION
    Checks the Dell Update Service version registry value and verifies it is at
    least version 5.7.1.558. Dell Command | Update does not reliably create an
    uninstall registry entry.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\detect-dcu-classic.ps1

.NOTES
    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$requiredVersion = [version]'5.7.1.558'
$versionRegistryPath = 'HKLM:\SOFTWARE\Dell\UpdateService\Service'
$versionRegistryValue = 'LastServiceStartVersion'
$logFolder = 'C:\Windows\Logs\Software'

try {
    if (-not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
    $logFile = Join-Path $logFolder 'dcu-classic-detect.log'
}
catch {
    $logFolder = $env:TEMP
    $logFile = Join-Path $logFolder 'dcu-classic-detect.log'
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
        # Local, non-elevated runs can be denied write access under C:\Windows\Logs; fall back to %TEMP% once.
        if ($script:logFile -ne (Join-Path $env:TEMP 'dcu-classic-detect.log')) {
            $script:logFile = Join-Path $env:TEMP 'dcu-classic-detect.log'
            try {
                $logLine | Out-File -FilePath $script:logFile -Append -Encoding utf8 -ErrorAction Stop
            }
            catch {
                # Best-effort only; nowhere left to fall back to.
            }
        }
    }
}

try {
    Write-Log "=== Starting Dell Command | Update Classic detection ==="
    Write-Log "Required version: $requiredVersion"

    $installedVersionValue = ([string](Get-ItemPropertyValue -Path $versionRegistryPath -Name $versionRegistryValue -ErrorAction Stop)).Trim()
    Write-Log "Found ${versionRegistryValue}: $installedVersionValue"

    try {
        $installedVersion = [version]$installedVersionValue
        if ($installedVersion -ge $requiredVersion) {
            Write-Log "Detected compliant version: $installedVersion"
            Write-Output "Detected"
            exit 0
        }
        Write-Log "Detected older version: $installedVersion; required >= $requiredVersion" -Level Warning
    }
    catch {
        Write-Log "Unable to parse $versionRegistryValue value $installedVersionValue as [version]" -Level Warning
    }

    Write-Log "Dell Command | Update Classic not detected or not compliant" -Level Warning
    exit 1
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
