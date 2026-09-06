<#
.SYNOPSIS
    Sets the active network connection for a specified Wi-Fi SSID to Private.

.DESCRIPTION
    Locates the active network connection whose profile name exactly matches the
    supplied SSID and changes its network category to Private. The SSID must be
    connected when this script runs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Ssid
)

$ErrorActionPreference = 'Stop'

$logFolder = 'C:\Windows\Logs\Software'
if (-not (Test-Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

$logFile = Join-Path $logFolder 'NetworkSsidPrivate-install.log'

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
    Write-Log "Starting network category configuration for SSID '$Ssid'."
    $profiles = @(Get-NetConnectionProfile | Where-Object { $_.Name -eq $Ssid })

    if ($profiles.Count -eq 0) {
        Write-Log "No active connection was found for SSID '$Ssid'." -Level Warning
        throw "No active network connection was found for SSID '$Ssid'. Connect to the SSID before running this script."
    }

    foreach ($profile in $profiles) {
        if ($profile.NetworkCategory -ne 'Private') {
            Write-Log "Setting interface '$($profile.InterfaceAlias)' to Private."
            Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private
        }
        else {
            Write-Log "Interface '$($profile.InterfaceAlias)' is already Private."
        }
    }

    $nonPrivateProfiles = @(Get-NetConnectionProfile |
        Where-Object { $_.Name -eq $Ssid -and $_.NetworkCategory -ne 'Private' })

    if ($nonPrivateProfiles.Count -gt 0) {
        Write-Log "SSID '$Ssid' still has a non-private active profile after configuration." -Level Error
        throw "The network profile for SSID '$Ssid' could not be set to Private."
    }

    $registryPath = 'HKLM:\SOFTWARE\Intune\NetworkSsidPrivate'
    if (-not (Test-Path $registryPath)) {
        Write-Log "Creating detection registry path '$registryPath'."
        New-Item -Path $registryPath -Force | Out-Null
    }

    New-ItemProperty -Path $registryPath -Name 'Ssid' -Value $Ssid -PropertyType String -Force | Out-Null

    Write-Log "Network profile for SSID '$Ssid' is Private and detection marker was recorded."
    Write-Output "Network profile for SSID '$Ssid' is Private."
    exit 0
}
catch {
    Write-Log "Installation failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    Write-Error $_.Exception.Message
    exit 1
}