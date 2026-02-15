# Error handling
$ErrorActionPreference = "Stop"

# Paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ScriptRoot "config"
$RepoRoot = Split-Path -Parent $ScriptRoot

$InstallerRootPath = Join-Path $RepoRoot "installers"
$IntuneUtilPath = Join-Path $ScriptRoot "IntuneWinAppUtil.exe"

function Read-AppConfigs {
    param([string]$ConfigDirectory)

    if (-not (Test-Path $ConfigDirectory)) {
        throw "Configuration directory not found: $ConfigDirectory"
    }

    $configs = @()
    $files = Get-ChildItem -Path $ConfigDirectory -Filter "*.json" -ErrorAction Stop
    foreach ($file in $files) {
        $cfg = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        if (-not $cfg.name) { continue }
        if (-not $cfg.versions) { continue }
        $configs += $cfg
    }

    if ($configs.Count -eq 0) {
        throw "No valid app config files found in $ConfigDirectory"
    }

    return ($configs | Sort-Object -Property name)
}

function Select-Option {
    param(
        [Parameter(Mandatory)][array]$Options,
        [Parameter(Mandatory)][string]$Prompt,
        [int]$DefaultIndex = 0
    )

    Write-Host $Prompt -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host ("{0}. {1}" -f ($i + 1), $Options[$i])
    }

    $inputMsg = "Enter the number of your selection (1-{0}) [default: {1}]" -f $Options.Count, ($DefaultIndex + 1)
    $selection = Read-Host $inputMsg
    if ([string]::IsNullOrWhiteSpace($selection)) { $selection = $DefaultIndex + 1 }

    if (-not ([int]::TryParse($selection, [ref]$null))) {
        throw "Invalid selection: $selection"
    }

    $idx = [int]$selection - 1
    if ($idx -lt 0 -or $idx -ge $Options.Count) {
        throw "Selection out of range"
    }

    return $Options[$idx]
}

try {
    if (-not (Test-Path $IntuneUtilPath)) {
        throw "IntuneWinAppUtil.exe not found at: $IntuneUtilPath"
    }

    $apps = Read-AppConfigs -ConfigDirectory $ConfigDir

    $appNames = $apps | ForEach-Object { $_.name }
    $selectedAppName = Select-Option -Options $appNames -Prompt "Select an application:" -DefaultIndex 0
    $appConfig = $apps | Where-Object { $_.name -eq $selectedAppName }

    Write-Host "Selected app: $($appConfig.name)" -ForegroundColor Green

    $versionNames = $appConfig.versions.PSObject.Properties.Name
    $selectedVersion = Select-Option -Options $versionNames -Prompt "`nSelect a version for $($appConfig.name):" -DefaultIndex 0

    $relativeInstallerPath = $appConfig.versions.$selectedVersion
    if (-not $relativeInstallerPath) {
        throw "Version path not found for selection: $selectedVersion"
    }

    $installerPath = Join-Path $InstallerRootPath $relativeInstallerPath
    if (-not (Test-Path $installerPath)) {
        throw "Installer not found at: $installerPath"
    }

    $sourceDir = Split-Path -Parent $installerPath
    $setupFileName = Split-Path -Leaf $installerPath
    if (-not (Test-Path $sourceDir)) {
        throw "Source directory not found: $sourceDir"
    }

    $packageDir = Join-Path (Split-Path -Parent $sourceDir) "package"
    if (-not (Test-Path $packageDir)) {
        New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    }

    Write-Host "`nInstaller path: $installerPath" -ForegroundColor Gray
    Write-Host "Source directory: $sourceDir" -ForegroundColor Gray
    Write-Host "Package output directory: $packageDir" -ForegroundColor Gray
    Write-Host "Packager executable: $IntuneUtilPath" -ForegroundColor Gray

    Write-Host "`nCreating package for $($appConfig.name) version $selectedVersion..." -ForegroundColor Green
    if ($appConfig.downloadUrl) { Write-Host "Download URL: $($appConfig.downloadUrl)" -ForegroundColor Gray }

    Write-Host "Using setup file: $setupFileName" -ForegroundColor Gray

    $packagerArgs = @('-c', $sourceDir, '-s', $setupFileName, '-o', $packageDir, '-q')
    Write-Host "`nRunning packager: $IntuneUtilPath $($packagerArgs -join ' ')" -ForegroundColor Yellow

    & $IntuneUtilPath @packagerArgs
    $exitCode = $LASTEXITCODE
    Write-Host "Packager completed with exit code: $exitCode" -ForegroundColor Gray

    $intunewin = Get-ChildItem -Path $packageDir -Filter "*.intunewin" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($intunewin) {
        Write-Host "Package created successfully!" -ForegroundColor Green
        Write-Host "Package file: $($intunewin.FullName)" -ForegroundColor Green
    } else {
        Write-Host "No .intunewin file found in output directory." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`nScript completed." -ForegroundColor Cyan
Write-Host "Press Enter to exit..." -ForegroundColor Yellow
Read-Host
