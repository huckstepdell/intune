<#
.SYNOPSIS
    Uninstall a Winget package for Intune Win32.

.DESCRIPTION
    Uses Winget to uninstall the package in system context.
    Logs to: C:\Windows\Logs\Software\<PackageId>-<Version>-uninstall.log
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$PackageId,

    [Parameter(Mandatory = $false)]
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

# Dot-source helper function from same directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "Get-WingetPath.ps1")

# Logging
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($Version) -or $Version -eq "Latest") {
    $LogFileName = "$PackageId-uninstall.log"
} else {
    $LogFileName = "$PackageId-$Version-uninstall.log"
}
$LogFileName = $LogFileName -replace '[\\/:*?"<>|]', '_'
$LogFile = Join-Path $LogFolder $LogFileName

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

try {
    Write-Log "Starting Winget uninstall. PackageId=$PackageId Version=$Version"

    $wingetPath = Get-WingetPath
    if (-not $wingetPath) {
        Write-Log "winget.exe not found (no DesktopAppInstaller x64 folder and not in PATH). Assuming package not installed."
        exit 0
    }

    Write-Log "Using winget: $wingetPath"

    $arguments = @(
        "uninstall",
        "--id", $PackageId,
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--source", "winget"
    )

    Write-Log "Running: `"$wingetPath`" $($arguments -join ' ')"

    $process = Start-Process -FilePath $wingetPath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden

    Write-Log "winget exit code: $($process.ExitCode)"

    # Non-zero often means "not found"; treat as success for idempotency
    if ($process.ExitCode -ne 0) {
        Write-Log "Non-zero exit code during uninstall; treating as success assuming package may already be removed."
    }

    Write-Log "Uninstall step completed."
    exit 0
}
catch {
    Write-Log "Error during uninstall: $($_.Exception.Message)"
    exit 1
}