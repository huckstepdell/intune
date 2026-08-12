#Requires -Version 5.1
<#
.SYNOPSIS
    Extracts the associated icon from an EXE and saves it as a PNG.

.DESCRIPTION
    Prompts for a source EXE path and a destination PNG path (or accepts them as parameters),
    extracts the file's associated icon via System.Drawing, and saves it as a PNG.
    Creates the destination folder if it does not already exist.

.PARAMETER SourceExe
    Path to the EXE (or any file with an associated icon) to extract the icon from.
    If omitted, you will be prompted for it.

.PARAMETER DestinationPng
    Path to the PNG file to create. If omitted, you will be prompted for it.

.EXAMPLE
    .\scripts\Export-IconFromExe.ps1

.EXAMPLE
    .\scripts\Export-IconFromExe.ps1 -SourceExe "C:\Program Files\Dell\DMA\bin\AgentInstallerHelper.exe" -DestinationPng "C:\temp\ddma.png"
#>

[CmdletBinding()]
param(
    [string]$SourceExe,
    [string]$DestinationPng
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not $SourceExe) {
    $SourceExe = Read-Host "Path to source EXE"
}

if (-not $DestinationPng) {
    $DestinationPng = Read-Host "Path to destination PNG"
}

if (-not (Test-Path $SourceExe)) {
    throw "Source EXE not found: $SourceExe"
}

$destinationDir = Split-Path $DestinationPng -Parent
if ($destinationDir -and -not (Test-Path $destinationDir)) {
    New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
}

$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SourceExe)
if ($null -eq $icon) {
    throw "No associated icon found in: $SourceExe"
}

$bitmap = $icon.ToBitmap()
try {
    $bitmap.Save($DestinationPng, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Icon saved to: $DestinationPng" -ForegroundColor Green
}
finally {
    $bitmap.Dispose()
    $icon.Dispose()
}
