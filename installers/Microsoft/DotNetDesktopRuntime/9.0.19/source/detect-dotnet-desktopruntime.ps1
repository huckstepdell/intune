<#
.SYNOPSIS
    Detection script for .NET Desktop Runtime 9.x

.DESCRIPTION
    Uses 'dotnet --list-runtimes' to check whether Microsoft.WindowsDesktop.App
    is installed at least at version 9.0.19 within the 9.x band. Runtimes are
    side-by-side, and this app may be superseded by a later 9.x patch applied
    through Dell Command | Update or Windows Update, which should still be compliant.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\detect-dotnet-desktopruntime.ps1

.NOTES
    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$runtimeName = 'Microsoft.WindowsDesktop.App'
$requiredVersion = [version]'9.0.19'
$majorVersion = 9
$logFolder = 'C:\Windows\Logs\Software'

try {
    if (-not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
    $logFile = Join-Path $logFolder 'dotnet-desktopruntime-9-detect.log'
}
catch {
    $logFolder = $env:TEMP
    $logFile = Join-Path $logFolder 'dotnet-desktopruntime-9-detect.log'
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
    Write-Log "=== Starting .NET Desktop Runtime $majorVersion.x detection ==="
    Write-Log "Required version: $requiredVersion"

    $output = & dotnet --list-runtimes 2>$null

    if (-not $output) {
        Write-Log "'dotnet --list-runtimes' returned no output; dotnet host may not be installed" -Level Warning
        exit 1
    }

    foreach ($line in $output) {
        if ($line -match '^(?<name>\S+)\s+(?<version>\d+\.\d+\.\d+)') {
            $name = $Matches['name']
            $versionText = $Matches['version']

            if ($name -ne $runtimeName) { continue }

            try {
                $installedVersion = [version]$versionText
            }
            catch {
                continue
            }

            if ($installedVersion.Major -ne $majorVersion) { continue }

            Write-Log "Found runtime: $name $installedVersion"

            if ($installedVersion -ge $requiredVersion) {
                Write-Log "Detected compliant version: $installedVersion"
                Write-Output "Detected"
                exit 0
            }
            else {
                Write-Log "Detected older version: $installedVersion; required >= $requiredVersion" -Level Warning
            }
        }
    }

    Write-Log ".NET Desktop Runtime $majorVersion.x not detected or not compliant" -Level Warning
    exit 1
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)" -Level Error
    exit 1
}
