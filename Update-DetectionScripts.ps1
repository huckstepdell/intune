# Script to update all detection scripts with new template structure
$ErrorActionPreference = "Stop"

$wingetDir = "c:\Users\colin\repos\intune\installers\winget"
$templateFile = Join-Path $wingetDir "_detect-winget-package.ps1"

# Read template sections
$templateContent = Get-Content $templateFile -Raw

# Extract the functions from template
$compareFunctionStart = $templateContent.IndexOf("function Compare-Versions {")
$compareFunctionEnd = $templateContent.IndexOf("function Get-WingetPath {")
$compareFunction = $templateContent.Substring($compareFunctionStart, $compareFunctionEnd - $compareFunctionStart).Trim()

$getUserProfilesStart = $templateContent.IndexOf("function Get-UserProfiles {")
$getUserProfilesEnd = $templateContent.IndexOf("function Test-UserContextInstallation {")
$getUserProfilesFunction = $templateContent.Substring($getUserProfilesStart, $getUserProfilesEnd - $getUserProfilesStart).Trim()

$testUserContextStart = $templateContent.IndexOf("function Test-UserContextInstallation {")
$testUserContextEnd = $templateContent.IndexOf("function Invoke-SystemContextDetection {")
$testUserContextFunction = $templateContent.Substring($testUserContextStart, $testUserContextEnd - $testUserContextStart).Trim()

$invokeSystemStart = $templateContent.IndexOf("function Invoke-SystemContextDetection {")
$invokeSystemEnd = $templateContent.IndexOf("# --- Main logic ---", $invokeSystemStart)
$invokeSystemFunction = $templateContent.Substring($invokeSystemStart, $invokeSystemEnd - $invokeSystemStart).Trim()

$mainLogicStart = $templateContent.IndexOf("# --- Main logic ---")
$mainLogic = $templateContent.Substring($mainLogicStart).Trim()

# Files to update (excluding template and already-updated files)
$filesToUpdate = @(
    "detect-Google.GoogleDrive.ps1",
    "detect-Logitech.OptionsPlus.ps1",
    "detect-MasterPackager.MasterPackager.ps1",
    "detect-Microsoft.VisualStudioCode.ps1",
    "detect-Musescore.Musescore.ps1",
    "detect-Omnissa.HorizonClient.ps1",
    "detect-Python.Python.3.14.ps1",
    "detect-Rufus.Rufus.ps1",
    "detect-Starship.Starship.ps1",
    "detect-Tailscale.Tailscale.ps1",
    "detect-Valve.Steam.ps1",
    "detect-Microsoft.DotNet.AspNetCore.10.ps1",
    "detect-Microsoft.DotNet.AspNetCore.8.ps1",
    "detect-Microsoft.DotNet.AspNetCore.9.ps1",
    "detect-Microsoft.DotNet.DesktopRuntime.10.ps1",
    "detect-Microsoft.DotNet.DesktopRuntime.8.ps1",
    "detect-Microsoft.DotNet.DesktopRuntime.9.ps1"
)

foreach ($file in $filesToUpdate) {
    $filePath = Join-Path $wingetDir $file
    if (-not (Test-Path $filePath)) {
        Write-Warning "File not found: $file"
        continue
    }

    Write-Host "Processing $file..." -ForegroundColor Cyan

    $content = Get-Content $filePath -Raw

    # Check if file already has the new structure
    if ($content -match 'InstallContext|Get-UserProfiles|Test-UserContextInstallation|Invoke-SystemContextDetection') {
        Write-Host "  Skipping (already updated)" -ForegroundColor Yellow
        continue
    }

    # 1. Extract existing parameters (keep PackageId, RequiredVersion, Source values)
    if ($content -match 'PackageId\s*=\s*"([^"]+)"') {
        $packageId = $Matches[1]
    }
    if ($content -match 'RequiredVersion\s*=\s*"([^"]+)"') {
        $requiredVersion = $Matches[1]
    }

    # 2. Replace parameters section
    $paramSection = @"
[CmdletBinding()]
Param(
    # Set these defaults per app when you copy this script
    [string]`$PackageId       = "$packageId",
    [string]`$RequiredVersion = "$requiredVersion",
    [string]`$Source          = "winget",

    # Install context - determines detection method
    [ValidateSet('System', 'User', 'Auto')]
    [string]`$InstallContext  = "System",

    # For user-context detection: file paths to check (relative to user profile)
    # Example: @("AppData\Local\Discord\app-*\Discord.exe")
    [string[]]`$UserContextPaths = @(),

    # For user-context detection: registry keys to check (relative to HKCU)
    # Example: @("Software\Discord")
    [string[]]`$UserContextRegistryKeys = @()
)
"@

    $content = $content -replace '(?s)\[CmdletBinding\(\)\][^\$]*Param\([^)]+\)', $paramSection

    # 3. Add Compare-Versions function after Write-Log if not present
    if ($content -notmatch 'function Compare-Versions') {
        $writeLogEnd = $content.IndexOf("function Get-WingetPath {")
        if ($writeLogEnd -gt 0) {
            $beforeGet = $content.Substring(0, $writeLogEnd)
            $afterGet = $content.Substring($writeLogEnd)
            $content = $beforeGet + "`n" + $compareFunction + "`n`n" + $afterGet
        }
    }

    # 4. Add the three user-context functions after Get-WingetPath
    $getWingetEnd = $content.IndexOf("# --- Main logic ---")
    if ($getWingetEnd -gt 0) {
        $beforeMain = $content.Substring(0, $getWingetEnd)
        $afterMain = $content.Substring($getWingetEnd)

        # Check if functions already exist
        if ($beforeMain -notmatch 'function Get-UserProfiles') {
            $beforeMain = $beforeMain.TrimEnd() + "`n`n" + $getUserProfilesFunction + "`n`n"
        }
        if ($beforeMain -notmatch 'function Test-UserContextInstallation') {
            $beforeMain = $beforeMain.TrimEnd() + $testUserContextFunction + "`n`n"
        }
        if ($beforeMain -notmatch 'function Invoke-SystemContextDetection') {
            $beforeMain = $beforeMain.TrimEnd() + $invokeSystemFunction + "`n`n"
        }

        $content = $beforeMain + $afterMain
    }

    # 5. Replace main logic
    $mainLogicStart = $content.IndexOf("# --- Main logic ---")
    if ($mainLogicStart -gt 0) {
        $content = $content.Substring(0, $mainLogicStart) + $mainLogic
    }

    # Save the file
    $content | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline
    Write-Host "  Updated successfully" -ForegroundColor Green
}

Write-Host "`nUpdate complete!" -ForegroundColor Green
