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
    [string]$PackageId       = "Logitech.OptionsPlus",
    [string]$RequiredVersion = "Latest",
    [string]$Source          = "winget",

    # Install context - determines detection method
    [ValidateSet('System', 'User', 'Auto')]
    [string]$InstallContext  = "System",

    # For user-context detection: file paths to check (relative to user profile)
    # Example: @("AppData\Local\Discord\app-*\Discord.exe")
    [string[]]$UserContextPaths = @(),

    # For user-context detection: registry keys to check (relative to HKCU)
    # Example: @("Software\Discord")
    [string[]]$UserContextRegistryKeys = @()
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($RequiredVersion) -or $RequiredVersion -eq "Latest") {
        $LogFileName = "$PackageId-detect.log"
    } else {
        $LogFileName = "$PackageId-$RequiredVersion-detect.log"
    }
    $LogFileName = $LogFileName -replace '[\\/:*?"<>|]', '_'
    $LogFile = Join-Path $LogFolder $LogFileName
}
catch {
    # Fallback to TEMP if we can't create/access the log folder
    $LogFolder = $env:TEMP
    if ([string]::IsNullOrWhiteSpace($RequiredVersion) -or $RequiredVersion -eq "Latest") {
        $LogFileName = "$PackageId-detect.log"
    } else {
        $LogFileName = "$PackageId-$RequiredVersion-detect.log"
    }
    $LogFileName = $LogFileName -replace '[\\/:*?"<>|]', '_'
    $LogFile = Join-Path $LogFolder $LogFileName
}

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
    try {
        $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction Stop
    }
    catch {
        # Silently fail if we can't write logs (will work in Intune as SYSTEM)
    }
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

function Get-UserProfiles {
    <#
    .SYNOPSIS
        Enumerate all user profiles on the system (excluding system accounts)
    #>
    $profiles = @()

    # Get profiles from C:\Users
    $userFolders = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') -and
            $_.Name -notmatch '^(Administrator|Guest)$'
        }

    foreach ($folder in $userFolders) {
        # Try to get the user's SID from the registry
        $profilePath = $folder.FullName
        $profileItem = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.ProfileImagePath -eq $profilePath } |
            Select-Object -First 1

        if ($profileItem) {
            $sid = Split-Path $profileItem.PSPath -Leaf
            $profiles += [PSCustomObject]@{
                Username    = $folder.Name
                ProfilePath = $profilePath
                SID         = $sid
            }
        } else {
            # No SID found, add without it
            $profiles += [PSCustomObject]@{
                Username    = $folder.Name
                ProfilePath = $profilePath
                SID         = $null
            }
        }
    }

    return $profiles
}

function Test-UserContextInstallation {
    <#
    .SYNOPSIS
        Check if the app is installed in any user's profile via file/registry detection
    #>
    param(
        [string]$PackageId,
        [string[]]$FilePaths,
        [string[]]$RegistryKeys
    )

    $profiles = Get-UserProfiles
    Write-Log "Checking user-context installation across $($profiles.Count) user profile(s)"

    foreach ($profile in $profiles) {
        Write-Log "Checking profile: $($profile.Username) ($($profile.ProfilePath))"

        # Check file-based detection
        foreach ($pathPattern in $FilePaths) {
            $fullPath = Join-Path $profile.ProfilePath $pathPattern
            Write-Log "  Checking file path: $fullPath"

            # Handle wildcards in path
            if ($fullPath -match '\*') {
                $resolved = Resolve-Path $fullPath -ErrorAction SilentlyContinue
                if ($resolved) {
                    Write-Log "  Found: $($resolved.Path)"
                    return $true
                }
            } else {
                if (Test-Path $fullPath) {
                    Write-Log "  Found: $fullPath"
                    return $true
                }
            }
        }

        # Check registry-based detection (load user hive if needed)
        if ($RegistryKeys.Count -gt 0 -and $profile.SID) {
            foreach ($regKey in $RegistryKeys) {
                # Check if hive is already loaded
                $hivePath = "Registry::HKEY_USERS\$($profile.SID)\$regKey"
                Write-Log "  Checking registry: $hivePath"

                if (Test-Path $hivePath) {
                    Write-Log "  Found: $hivePath"
                    return $true
                }
            }
        }
    }

    Write-Log "No user-context installation found across all profiles"
    return $false
}

function Invoke-SystemContextDetection {
    <#
    .SYNOPSIS
        Perform system-context detection using winget list
    #>
    param(
        [string]$PackageId,
        [string]$RequiredVersion,
        [string]$Source
    )

    Write-Log "=== Running SYSTEM context detection via winget list ==="

    $wingetPath = Get-WingetPath
    if (-not $wingetPath) {
        Write-Log "winget.exe not found (no DesktopAppInstaller x64 folder and not in PATH)." -Level Warning
        return $false
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
        Write-Log "No output from winget list; not installed in system context." -Level Warning
        return $false
    }

    $output | ForEach-Object { Write-Log "winget list: $_" }

    # Sanitize text output (remove control/progress characters) and parse
    $cleanLines = $output | ForEach-Object { ($_ -replace '[\p{Cc}]','').Trim() } |
                  Where-Object { $_ -and ($_ -notmatch '^[-\\|/\s]+$') -and ($_ -notmatch 'MB\s*/') }

    $cleanLines | ForEach-Object { Write-Log "winget cleaned: $_" }

    if (-not $RequiredVersion -or $RequiredVersion -eq "Latest") {
        $line = $cleanLines | Select-String -SimpleMatch $PackageId | Select-Object -First 1
        if ($null -eq $line) {
            Write-Log "PackageId not found in output and RequiredVersion=Latest; not installed."
            return $false
        }

        $lineText = $line.ToString()
        Write-Log "Found package line: $lineText"

        # Try to find version numbers in the line (installed and optional available)
        $versionPattern = '\b\d+(?:\.\d+)+(?:-[^\s]+)?\b'
        $versions = [regex]::Matches($lineText, $versionPattern) | ForEach-Object { $_.Value }

        if ($versions.Count -ge 2) {
            $installedVersion = $versions[0]
            $availableVersion = $versions[1]

            # Some package names include version text; compare explicit version values before deciding.
            $latestComparison = Compare-Versions -InstalledVersion $installedVersion -RequiredVersion $availableVersion

            if ($latestComparison -lt 0) {
                Write-Log "Update available: Installed=$installedVersion, Available=$availableVersion" -Level Warning
                return $false
            }

            if ($latestComparison -eq 0) {
                Write-Log "Package is installed with version $installedVersion and is up to date."
                return $true
            }

            Write-Log "Installed version $installedVersion is newer than available version $availableVersion; treating as compliant."
            return $true
        }
        elseif ($versions.Count -eq 1) {
            Write-Log "Package is installed with version $($versions[0]) and is up to date."
            return $true
        }
        else {
            Write-Log "PackageId found but could not parse version information." -Level Warning
            return $true
        }
    }

    $matchLine = $cleanLines | Select-String -SimpleMatch $PackageId | Select-Object -First 1
    if ($null -eq $matchLine) {
        Write-Log "No line containing PackageId found in winget output; not installed."
        return $false
    }

    $lineText = $matchLine.ToString()
    $verRegex = [regex]'\b\d+(?:\.\d+)+(?:-[^\s]+)?\b'
    $verMatch = $verRegex.Match($lineText)
    if (-not $verMatch.Success) {
        Write-Log "Could not parse installed version from: $lineText" -Level Error
        return $false
    }

    $installedVersion = $verMatch.Value
    Write-Log "Parsed installed version: $installedVersion"

    # Compare versions - accept equal or newer versions
    $comparison = Compare-Versions -InstalledVersion $installedVersion -RequiredVersion $RequiredVersion

    if ($comparison -ge 0) {
        if ($comparison -eq 0) {
            Write-Log "Installed version ($installedVersion) matches required version ($RequiredVersion)."
        } else {
            Write-Log "Installed version ($installedVersion) is newer than required version ($RequiredVersion)."
        }
        return $true
    }
    else {
        Write-Log "Installed version ($installedVersion) is older than required version ($RequiredVersion)." -Level Warning
        return $false
    }
}

# --- Main logic ---
try {
    Write-Log "=== Starting detection for PackageId=$PackageId RequiredVersion=$RequiredVersion InstallContext=$InstallContext ==="

    $isDetected = $false

    switch ($InstallContext) {
        'System' {
            $isDetected = Invoke-SystemContextDetection -PackageId $PackageId -RequiredVersion $RequiredVersion -Source $Source
        }

        'User' {
            if ($UserContextPaths.Count -eq 0 -and $UserContextRegistryKeys.Count -eq 0) {
                Write-Log "InstallContext=User requires UserContextPaths or UserContextRegistryKeys to be specified." -Level Error
                exit 1
            }

            $isDetected = Test-UserContextInstallation -PackageId $PackageId -FilePaths $UserContextPaths -RegistryKeys $UserContextRegistryKeys
        }

        'Auto' {
            # Try system detection first
            $isDetected = Invoke-SystemContextDetection -PackageId $PackageId -RequiredVersion $RequiredVersion -Source $Source

            # If not found and user context detection is configured, try user detection
            if (-not $isDetected -and ($UserContextPaths.Count -gt 0 -or $UserContextRegistryKeys.Count -gt 0)) {
                Write-Log "Not found in system context, attempting user context detection..."
                $isDetected = Test-UserContextInstallation -PackageId $PackageId -FilePaths $UserContextPaths -RegistryKeys $UserContextRegistryKeys
            }
        }
    }

    if ($isDetected) {
        Write-Log "=== Detection complete: DETECTED ==="
        Write-Output "Detected"
        exit 0
    } else {
        Write-Log "=== Detection complete: NOT DETECTED ===" -Level Warning
        exit 1
    }
}
catch {
    Write-Log "Unexpected error in detection: $($_.Exception.Message)" -Level Error
    exit 1
}

