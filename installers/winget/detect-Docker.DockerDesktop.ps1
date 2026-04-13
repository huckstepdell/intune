<#
.SYNOPSIS
    Generic detection for Winget packages for Intune Win32 apps.

.DESCRIPTION
    Exit codes:
      0 -> App detected and compliant
      1 -> App not detected / non-compliant

    Defaults:
      PackageId       = 'CHANGE.ME'   # e.g. 'Dell.CommandUpdate.Universal'
      RequiredVersion = 'Latest'     # or a specific version, e.g. '5.6.0'
#>

[CmdletBinding()]
Param(
    # Set these defaults per app when you copy this script
    [string]$PackageId       = "Docker.DockerDesktop",
    [string]$RequiredVersion = "Latest",
    [string]$Source          = "winget"
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($RequiredVersion) -or $RequiredVersion -eq "Latest") {
    $LogFileName = "$PackageId-detect.log"
} else {
    $LogFileName = "$PackageId-$RequiredVersion-detect.log"
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
    $callerInfo = (Get-PSCallStack)[1]
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

function Compare-Versions {
    param(
        [string]$InstalledVersion,
        [string]$RequiredVersion
    )

    # Split versions into parts, handling pre-release tags (e.g., "1.2.3-beta")
    $installedParts = ($InstalledVersion -split '-')[0] -split '\.'
    $requiredParts = ($RequiredVersion -split '-')[0] -split '\.'

    # Pad arrays to same length
    $maxLength = [Math]::Max($installedParts.Count, $requiredParts.Count)
    while ($installedParts.Count -lt $maxLength) { $installedParts += "0" }
    while ($requiredParts.Count -lt $maxLength) { $requiredParts += "0" }

    # Compare each part
    for ($i = 0; $i -lt $maxLength; $i++) {
        $installedNum = [int]$installedParts[$i]
        $requiredNum = [int]$requiredParts[$i]

        if ($installedNum -gt $requiredNum) {
            return 1  # Installed is newer
        }
        elseif ($installedNum -lt $requiredNum) {
            return -1  # Installed is older
        }
    }

    return 0  # Versions are equal
}

function Get-WingetPath {
    # 1) Prefer DesktopAppInstaller x64 folder in Program Files\WindowsApps
    $windowsApps = "C:\Program Files\WindowsApps"
    if (Test-Path $windowsApps) {
        $candidate = Get-ChildItem -Path $windowsApps -Directory -Filter "Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending |
                     Select-Object -First 1

        if ($candidate) {
            $possibleWinget = Join-Path $candidate.FullName "winget.exe"
            if (Test-Path $possibleWinget) {
                return $possibleWinget
            }
        }
    }

    # 2) Fallback: PATH
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

# --- Main logic ---
try {
    Write-Log "=== Starting detection for PackageId=$PackageId RequiredVersion=$RequiredVersion ==="

    $wingetPath = Get-WingetPath
    if (-not $wingetPath) {
        Write-Log "winget.exe not found (no DesktopAppInstaller x64 folder and not in PATH). Returning not detected." -Level Error
        exit 1
    }

    Write-Log "Using winget: $wingetPath"

    $arguments = @(
        "list",
        "--id", $PackageId,
        "--accept-source-agreements"
    )

    if ($Source) {
        $arguments += @("--source", $Source)
    }

    Write-Log "Running: `"$wingetPath`" $($arguments -join ' ')"

    $output = & $wingetPath @arguments 2>&1

    if (-not $output) {
        Write-Log "No output from winget list; treating as not installed." -Level Warning
        exit 1
    }

    $output | ForEach-Object { Write-Log "winget list: $_" }

    # Note: not attempting JSON parsing here because some winget builds
    # do not accept an explicit JSON output flag; rely on robust text parsing below.

    # Fallback: sanitize text output (remove control/progress characters) and parse
    $cleanLines = $output | ForEach-Object { ($_ -replace '[\p{Cc}]','').Trim() } |
                  Where-Object { $_ -and ($_ -notmatch '^[-\\|/\s]+$') -and ($_ -notmatch 'MB\s*/') }

    $cleanLines | ForEach-Object { Write-Log "winget cleaned: $_" }

    if (-not $RequiredVersion -or $RequiredVersion -eq "Latest") {
        $line = $cleanLines | Select-String -SimpleMatch $PackageId | Select-Object -First 1
        if ($null -eq $line) {
            Write-Log "PackageId not found in output and RequiredVersion=Latest; not installed." -Level Warning
            exit 1
        }

        $lineText = $line.ToString()
        Write-Log "Found package line: $lineText"

        # Check if there's an "Available" version (indicates update is available)
        # Format: "Name    Id    Version Available Source"
        # Split by whitespace and look for version patterns
        $tokens = $lineText -split '\s+' | Where-Object { $_ }

        # Try to find two version numbers in the line (installed and available)
        $versionPattern = '\b\d+(?:\.\d+)+(?:-[^\s]+)?\b'
        $versions = [regex]::Matches($lineText, $versionPattern) | ForEach-Object { $_.Value }

        if ($versions.Count -ge 2) {
            Write-Log "Update available: Installed=$($versions[0]), Available=$($versions[1])" -Level Warning
            exit 1
        }
        elseif ($versions.Count -eq 1) {
            Write-Log "Package is installed with version $($versions[0]) and is up to date (no Available column)."
            Write-Output "Detected"
            exit 0
        }
        else {
            Write-Log "PackageId found but could not parse version information." -Level Warning
            Write-Output "Detected"
            exit 0
        }
    }

    $matchLine = $cleanLines | Select-String -SimpleMatch $PackageId | Select-Object -First 1
    if ($null -eq $matchLine) {
        Write-Log "No line containing PackageId found in winget output; not installed."
        exit 1
    }

    $lineText = $matchLine.ToString()
    $verRegex = [regex]'\b\d+(?:\.\d+)+(?:-[^\s]+)?\b'
    $verMatch = $verRegex.Match($lineText)
    if (-not $verMatch.Success) {
        Write-Log "Could not parse installed version from: $lineText" -Level Error
        exit 1
    }

    $installedVersion = $verMatch.Value
    Write-Log "Parsed installed version: $installedVersion"

    # Compare versions - accept equal or newer versions
    $comparison = Compare-Versions -InstalledVersion $installedVersion -RequiredVersion $RequiredVersion

    if ($comparison -ge 0) {
        if ($comparison -eq 0) {
            Write-Log "Installed version ($installedVersion) matches required version ($RequiredVersion). Returning detected (0)."
        } else {
            Write-Log "Installed version ($installedVersion) is newer than required version ($RequiredVersion). Returning detected (0)."
        }
        Write-Output "Detected"
        exit 0
    }
    else {
        Write-Log "Installed version ($installedVersion) is older than required version ($RequiredVersion). Returning not detected (1)." -Level Warning
        exit 1
    }
}
catch {
    Write-Log "Unexpected error in detection: $($_.Exception.Message)" -Level Error
    exit 1
}
