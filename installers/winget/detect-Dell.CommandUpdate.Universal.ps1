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
    [string]$PackageId       = "Dell.CommandUpdate.Universal",
    [string]$RequiredVersion = "5.6.0",
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
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
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
        Write-Log "winget.exe not found (no DesktopAppInstaller x64 folder and not in PATH). Returning not detected."
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
        Write-Log "No output from winget list; treating as not installed."
        exit 1
    }

    $output | ForEach-Object { Write-Log "winget list: $_" }

    # --- Any version acceptable (RequiredVersion = Latest or empty) ---
    if (-not $RequiredVersion -or $RequiredVersion -eq "Latest") {
        $line = $output | Select-String -SimpleMatch $PackageId | Select-Object -First 1
        if ($null -eq $line) {
            Write-Log "PackageId not found in output and RequiredVersion=Latest; not installed."
            exit 1
        }

        Write-Log "PackageId found and RequiredVersion=Latest; returning detected."
        exit 0
    }

    # --- Specific version required ---
    $matchLine = $output | Select-String -SimpleMatch $PackageId | Select-Object -First 1
    if ($null -eq $matchLine) {
        Write-Log "No line containing PackageId found in winget output; not installed."
        exit 1
    }

    $tokens = $matchLine.ToString().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)

    # Typical winget list line: Name  Id  Version  Source
    $installedVersion = $tokens | Where-Object { $_ -match '^\d+(\.\d+)*' } | Select-Object -Last 1

    if (-not $installedVersion) {
        Write-Log "Could not parse installed version from: $($matchLine.ToString())"
        exit 1
    }

    Write-Log "Parsed installed version: $installedVersion"

    if ($installedVersion -eq $RequiredVersion) {
        Write-Log "Installed version matches required version. Returning detected (0)."
        exit 0
    }
    else {
        Write-Log "Installed version does not match required version. Returning not detected (1)."
        exit 1
    }
}
catch {
    Write-Log "Unexpected error in detection: $($_.Exception.Message)"
    exit 1
}