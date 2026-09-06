<#
.SYNOPSIS
    Detects whether the Network SSID Private Win32 app completed successfully.

.DESCRIPTION
    Reads the SSID marker written by Set-NetworkSsidPrivate.ps1 after it has
    confirmed the active network profile is Private.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Ssid = 'REPLACE-WITH-SSID'
)

$ErrorActionPreference = 'Stop'
$registryPath = 'HKLM:\SOFTWARE\Intune\NetworkSsidPrivate'

$logFolder = 'C:\Windows\Logs\Software'
try {
    if (-not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }

    $logFile = Join-Path $logFolder 'NetworkSsidPrivate-detect.log'
}
catch {
    $logFolder = $env:TEMP
    $logFile = Join-Path $logFolder 'NetworkSsidPrivate-detect.log'
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $logLevel = switch ($Level) {
        'Info' { 1 }
        'Warning' { 2 }
        'Error' { 3 }
    }

    $component = Split-Path -Leaf $MyInvocation.ScriptName
    $time = Get-Date -Format 'HH:mm:ss.fff'
    $date = Get-Date -Format 'MM-dd-yyyy'
    $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
    $timeZoneString = '{0:+000;-000}' -f $timeZoneBias
    $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

    $logLine | Out-File -FilePath $logFile -Append -Encoding utf8
}

try {
    Write-Log 'Starting Network SSID Private detection.'
    $ssid = Get-ItemPropertyValue -Path $registryPath -Name 'Ssid'

    if ([string]::IsNullOrWhiteSpace($ssid)) {
        Write-Log 'The configured SSID marker is empty.' -Level Warning
        throw 'The configured SSID marker is empty.'
    }

    if ($Ssid -and $ssid -ne $Ssid) {
        Write-Log "Configured SSID '$ssid' does not match required SSID '$Ssid'." -Level Warning
        throw "Configured SSID '$ssid' does not match required SSID '$Ssid'."
    }

    Write-Log "Detected configured private network SSID '$ssid'."
    Write-Output "Detected configured private network SSID: $ssid"
    exit 0
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Warning
    Write-Error "Network SSID Private is not detected: $($_.Exception.Message)"
    exit 1
}