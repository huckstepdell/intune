#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads the latest IntuneWinAppUtil.exe from the Microsoft Win32 Content Prep Tool GitHub releases.

.DESCRIPTION
    Checks if $HOME\repos\intune exists. If it does, downloads the latest IntuneWinAppUtil.exe
    directly from the Microsoft-Win32-Content-Prep-Tool GitHub repository (via the Contents API)
    and places it in $HOME\repos\intune\PackageGenerator.
    If the directory does not exist, the script exits without doing anything.

.EXAMPLE
    .\scripts\Update-IntuneWinAppUtil.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoPath = Join-Path $HOME 'repos\intune'

if (-not (Test-Path $repoPath)) {
    Write-Verbose "Directory '$repoPath' not found. Nothing to do."
    exit 0
}

$destinationDir  = Join-Path $repoPath 'PackageGenerator'
$destinationFile = Join-Path $destinationDir 'IntuneWinAppUtil.exe'

# The tool is committed directly to the repo (not shipped as a release asset).
# Use the Contents API so we always get the latest committed version.
$contentsUrl = 'https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/contents/IntuneWinAppUtil.exe'

Write-Host "Fetching latest IntuneWinAppUtil.exe info from GitHub..."
$headers  = @{ 'User-Agent' = 'PowerShell' }
$metadata = Invoke-RestMethod -Uri $contentsUrl -Headers $headers -ErrorAction Stop
Write-Host "SHA: $($metadata.sha)"

if (-not (Test-Path $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}

Write-Host "Downloading IntuneWinAppUtil.exe to '$destinationFile'..."
Invoke-WebRequest -Uri $metadata.download_url -OutFile $destinationFile -UseBasicParsing -ErrorAction Stop

Write-Host "Done. IntuneWinAppUtil.exe updated at '$destinationFile'."
