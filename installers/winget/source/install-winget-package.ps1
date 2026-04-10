<#
.SYNOPSIS
    Install a Winget package for Intune Win32, enforcing a specific version.

.DESCRIPTION
    Logic:
      - If Version = "Latest":
          * If any version is installed, treat as success (exit 0).
          * Otherwise, run winget install.
      - If Version is a specific version:
          * If that version is installed, do nothing (exit 0).
          * If a different version is installed, uninstall it, then install the required version.
          * If not installed, install the required version.

    Exit Code Handling:
      - 0: Success
      - 0x8A15002B: Success (no applicable update - package already at correct version)
        Note: This can occur due to winget metadata caching where 'winget list' shows
        an update available but 'winget upgrade' finds nothing to do.

    Logs to: C:\Windows\Logs\Software\<PackageId>-<Version>-install.log
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$PackageId,

    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Logging
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($Version) -or $Version -eq "Latest") {
    $LogFileName = "$PackageId-install.log"
} else {
    $LogFileName = "$PackageId-$Version-install.log"
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

function Get-WingetPath {
    # Prefer DesktopAppInstaller x64 folder
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

    # Fallback: PATH
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Get-WingetErrorHint {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    $hexCode = "0x{0:X8}" -f ($ExitCode -band 0xFFFFFFFF)
    $hint = switch ($hexCode) {
        "0x8A150014" { "No package found matching input criteria (check --id value and source)." }
        "0x8A15002B" { "No applicable update found (package already at correct version)." }
        default { "See winget logs and stderr output for details." }
    }

    return "$hexCode - $hint"
}

function Test-WingetSuccessCode {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    # Treat these exit codes as success
    $hexCode = "0x{0:X8}" -f ($ExitCode -band 0xFFFFFFFF)
    return ($ExitCode -eq 0) -or ($hexCode -eq "0x8A15002B")
}

try {
    Write-Log "Starting Winget install. PackageId=$PackageId Version=$Version"

    $wingetPath = Get-WingetPath
    if (-not $wingetPath) {
        Write-Log "winget.exe not found (no DesktopAppInstaller x64 folder and not in PATH)."
        throw "winget.exe not found"
    }

    Write-Log "Using winget: $wingetPath"

    # --- Pre-check: what version (if any) is currently installed? ---
    Write-Log "Checking current installed version via winget list."

    $checkArgs = @(
        "list",
        "--id", $PackageId,
        "--exact",
        "--accept-source-agreements"
    )

    $checkOutput = & $wingetPath @checkArgs 2>&1
    $installedVersion = $null
    $updateAvailable = $false

    if ($checkOutput) {
        $checkLine = $checkOutput | Select-String -SimpleMatch $PackageId | Select-Object -First 1
        if ($checkLine) {
            $lineText = $checkLine.ToString()
            Write-Log "Pre-check matched line: $lineText"

            # Remove the ">" symbol if present (indicates update available)
            $cleanedLine = $lineText -replace '>\s*', ''

            # Check for version numbers in the output, requiring at least major.minor format
            $versionPattern = '\b\d+(?:\.\d+)+(?:-[^\s]+)?\b'
            $versions = [regex]::Matches($cleanedLine, $versionPattern) | ForEach-Object { $_.Value }

            # Filter out any versions that look like they're from the app name (e.g., "1Password 8")
            # by preferring versions after the PackageId column
            $idIndex = $cleanedLine.IndexOf($PackageId)
            if ($idIndex -ge 0) {
                $afterId = $cleanedLine.Substring($idIndex + $PackageId.Length)
                $versionsAfterId = [regex]::Matches($afterId, $versionPattern) | ForEach-Object { $_.Value }
                if ($versionsAfterId.Count -gt 0) {
                    $versions = $versionsAfterId
                }
            }

            if ($versions.Count -ge 2) {
                # Two versions means: Installed and Available (update available)
                $installedVersion = $versions[0]
                $availableVersion = $versions[1]
                $updateAvailable = $true
                Write-Log "Pre-check found installed version: $installedVersion, Available version: $availableVersion"
            }
            elseif ($versions.Count -eq 1) {
                # One version means: Installed only
                $installedVersion = $versions[0]
                # Check if the original line had ">" which indicates update available
                if ($lineText -match '>') {
                    $updateAvailable = $true
                    Write-Log "Pre-check found installed version: $installedVersion (update available, indicated by >)"
                }
                else {
                    $updateAvailable = $false
                    Write-Log "Pre-check found installed version: $installedVersion (up to date)"
                }
            }
            else {
                Write-Log "Pre-check could not parse version from line: $lineText" -Level Warning
            }
        }
        else {
            Write-Log "Pre-check did not find a line with PackageId."
        }
    }
    else {
        Write-Log "Pre-check winget list returned no output."
    }

    # --- Decide what to do based on Version and installedVersion ---

    if ($Version -eq "Latest") {
        # Check if update is available
        if ($installedVersion -and -not $updateAvailable) {
            Write-Log "Package is already installed (version=$installedVersion) and is up to date. Skipping install."
            exit 0
        }
        elseif ($installedVersion -and $updateAvailable) {
            Write-Log "Package is installed (version=$installedVersion) but update appears available. Proceeding with upgrade."
            Write-Log "Note: If upgrade returns 'no applicable update', this may be due to winget metadata caching."
        }
        else {
            Write-Log "Package not installed; proceeding with install of Latest."
        }
    }
    else {
        # Specific version required
        if ($installedVersion -eq $Version) {
            Write-Log "Required version $Version is already installed. Skipping install."
            exit 0
        }
        elseif ($installedVersion) {
            Write-Log "Installed version '$installedVersion' does not match required '$Version'. Attempting uninstall before install."

            $uninstallArgs = @(
                "uninstall",
                "--id", $PackageId,
                "--exact",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--source", "winget"
            )

            Write-Log "Running uninstall: `"$wingetPath`" $($uninstallArgs -join ' ')"

            $uninstallStdOut = Join-Path $LogFolder "$PackageId-$Version-winget-uninstall-stdout.log"
            $uninstallStdErr = Join-Path $LogFolder "$PackageId-$Version-winget-uninstall-stderr.log"

            $uninstallProcess = Start-Process -FilePath $wingetPath `
                                              -ArgumentList $uninstallArgs `
                                              -Wait -PassThru -WindowStyle Hidden `
                                              -RedirectStandardOutput $uninstallStdOut `
                                              -RedirectStandardError  $uninstallStdErr

            Write-Log "winget uninstall exit code: $($uninstallProcess.ExitCode)"

            # Treat "not found" as success; otherwise just log and continue to install
            if ($uninstallProcess.ExitCode -ne 0) {
                Write-Log "Uninstall returned non-zero exit code; continuing with install anyway."
            }
        }
        else {
            Write-Log "Package not installed; proceeding with install of required version $Version."
        }
    }

    # --- Install (or reinstall) the required version ---
    $installArgs = @(
        "install",
        "--id", $PackageId,
        "--exact",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--source", "winget"
    )

    if ($Version -and $Version -ne "Latest") {
        $installArgs += @("--version", $Version)
    }

    Write-Log "Running install: `"$wingetPath`" $($installArgs -join ' ')"

    $stdoutLog = Join-Path $LogFolder "$PackageId-$Version-winget-install-stdout.log"
    $stderrLog = Join-Path $LogFolder "$PackageId-$Version-winget-install-stderr.log"

    Write-Log "Redirecting install STDOUT to: $stdoutLog"
    Write-Log "Redirecting install STDERR to: $stderrLog"

    $installProcess = Start-Process -FilePath $wingetPath `
                                    -ArgumentList $installArgs `
                                    -Wait -PassThru -WindowStyle Hidden `
                                    -RedirectStandardOutput $stdoutLog `
                                    -RedirectStandardError  $stderrLog

    Write-Log "winget install exit code: $($installProcess.ExitCode)"

    if (-not (Test-WingetSuccessCode -ExitCode $installProcess.ExitCode)) {
        $errorHint = Get-WingetErrorHint -ExitCode $installProcess.ExitCode
        throw "winget install failed with exit code $($installProcess.ExitCode) ($errorHint)"
    }

    $hexCode = "0x{0:X8}" -f ($installProcess.ExitCode -band 0xFFFFFFFF)
    if ($hexCode -eq "0x8A15002B") {
        Write-Log "Install completed successfully (package already at correct version)."
    } else {
        Write-Log "Install completed successfully."
    }
    exit 0
}
catch {
    Write-Log "Error during install: $($_.Exception.Message)" -Level Error
    exit 1
}