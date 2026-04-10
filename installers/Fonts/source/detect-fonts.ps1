<#
.SYNOPSIS
    Detection script for font installations via registry check.

.DESCRIPTION
    Checks if specific fonts are installed by verifying their registry entries.
    Exit codes:
      0 -> Font detected and compliant
      1 -> Font not detected / non-compliant

.PARAMETER FontName
    The font name pattern to search for in the registry (supports wildcards).
    Example: "Meslo LGS Mono*" will match all Meslo LGS Mono variants.
#>

[CmdletBinding()]
Param(
    [string]$FontName = "MesloLGSNerdFontMono-Regular (TrueType)"
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$safeLogName = $FontName -replace '[\\/:*?"<>|]', '_'
$LogFileName = "Font-$safeLogName-detect.log"
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

# --- Main logic ---
try {
    Write-Log "=== Starting font detection for: $FontName ==="

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    if (-not (Test-Path $regPath)) {
        Write-Log "Font registry path not found: $regPath" -Level Error
        exit 1
    }

    Write-Log "Checking registry path: $regPath"

    # Get all font registry entries
    $fonts = Get-ItemProperty -Path $regPath -ErrorAction Stop

    # Check if any font names match the pattern
    $matchingFonts = $fonts.PSObject.Properties | Where-Object {
        $_.Name -like $FontName
    }

    if ($matchingFonts) {
        Write-Log "Found matching fonts:"
        foreach ($font in $matchingFonts) {
            Write-Log "  - $($font.Name): $($font.Value)"
        }
        Write-Log "Font(s) detected. Returning compliant (exit 0)."
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "No fonts matching '$FontName' found in registry." -Level Warning
        exit 1
    }
}
catch {
    Write-Log "Unexpected error in detection: $($_.Exception.Message)" -Level Error
    exit 1
}
