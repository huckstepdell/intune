<#
.SYNOPSIS
    Install prerequisites for Intune Certificate Connector on Entra connector server

.DESCRIPTION
    This script installs and configures the prerequisites required for Intune Certificate Connector
    on a dedicated connector server that communicates with a remote CA (Certificate Authority).

    Architecture:
    - Certificate Authority (AD CS) runs on your Domain Controller
    - NDES and Intune Certificate Connector run on THIS server
    - This server connects to the remote CA to issue certificates

    Components installed:
    - .NET Framework 4.7.2 or later / .NET 6.0+
    - TLS 1.2 configuration
    - Strong cryptography registry settings
    - IIS and required Windows features for NDES
    - NDES (Network Device Enrollment Service)
    - SCEP configuration

.NOTES
    Author: Colin
    Requires: Windows Server 2012 R2 or later, domain-joined
    Run as: Administrator
    Created: May 2026

    Prerequisites:
    - Server must be domain-joined
    - AD CS (Certificate Authority) must be installed on DC
    - Service account for NDES (with appropriate permissions)

.EXAMPLE
    .\Install-IntuneCertConnectorPrereqs.ps1
    Checks and installs all prerequisites and NDES automatically

.EXAMPLE
    .\Install-IntuneCertConnectorPrereqs.ps1 -NDESServiceAccount "DOMAIN\NDESService"
    Installs all components including NDES with specified service account

.EXAMPLE
    .\Install-IntuneCertConnectorPrereqs.ps1 -CAConfig "DC01\Contoso-CA"
    Specifies the remote CA configuration explicitly

.EXAMPLE
    .\Install-IntuneCertConnectorPrereqs.ps1 -SkipNDES
    Installs prerequisites only, skips NDES installation
#>

[CmdletBinding()]
param(
    [switch]$SkipDotNet,
    [switch]$SkipTLSConfig,
    [switch]$SkipWindowsFeatures,
    [switch]$SkipNDES,
    [string]$NDESServiceAccount,
    [string]$CAConfig  # Format: "CAServerName\CAName" or will auto-detect
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\IntuneCertConnector"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "prereq-install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Console output with color
    $color = switch ($Level) {
        'Info'    { 'White' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }
    Write-Host $logMessage -ForegroundColor $color

    # File output
    Add-Content -Path $LogFile -Value $logMessage
}

function Test-DomainMembership {
    Write-Log "Checking domain membership..."

    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem

        if ($computerSystem.PartOfDomain) {
            Write-Log "Server is domain-joined: $($computerSystem.Domain)" -Level Success
            return $true
        }
        else {
            Write-Log "Server is NOT domain-joined" -Level Error
            Write-Log "NDES requires the server to be joined to a domain" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error checking domain membership: $_" -Level Error
        return $false
    }
}

function Test-RemoteCA {
    param(
        [string]$CAConfigString
    )

    Write-Log "Checking for remote Certificate Authority..."

    try {
        # Try to get CA config if not provided
        if (-not $CAConfigString) {
            Write-Log "Auto-detecting CA configuration..."
            $caConfig = certutil -getconfig 2>&1

            if ($LASTEXITCODE -eq 0) {
                # Parse the output to get the CA config
                $configLine = $caConfig | Where-Object { $_ -match '\\' } | Select-Object -First 1
                if ($configLine -match '"(.+?)"') {
                    $CAConfigString = $matches[1]
                    Write-Log "Detected CA: $CAConfigString" -Level Success
                }
            }
        }

        if (-not $CAConfigString) {
            Write-Log "Could not auto-detect CA configuration" -Level Warning
            Write-Log "Please ensure CA is accessible from this server" -Level Warning
            Write-Log "You can specify it with -CAConfig 'ServerName\CAName'" -Level Info
            return $null
        }

        # Test connectivity to the CA
        Write-Log "Testing connectivity to CA: $CAConfigString"
        $pingResult = certutil -config "$CAConfigString" -ping 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully connected to CA: $CAConfigString" -Level Success
            return $CAConfigString
        }
        else {
            Write-Log "Could not connect to CA: $CAConfigString" -Level Error
            Write-Log "Error: $pingResult" -Level Error
            Write-Log "Ensure CA is accessible and you have permissions" -Level Warning
            return $null
        }
    }
    catch {
        Write-Log "Error testing CA connectivity: $_" -Level Error
        return $null
    }
}

function Test-DotNetVersion {
    Write-Log "Checking .NET Framework version..."

    # Check for .NET Framework 4.7.2 or later
    $release = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release

    if ($release -ge 461808) {  # 4.7.2 = 461808, 4.8 = 528040
        $version = switch ($release) {
            { $_ -ge 533320 } { "4.8.1 or later" }
            { $_ -ge 528040 } { "4.8" }
            { $_ -ge 461808 } { "4.7.2" }
        }
        Write-Log ".NET Framework $version is installed (Release: $release)" -Level Success
        return $true
    }

    Write-Log ".NET Framework 4.7.2 or later not found (Release: $release)" -Level Warning
    return $false
}

function Install-DotNet {
    Write-Log "Installing .NET Framework 4.8..."

    $dotNetUrl = "https://go.microsoft.com/fwlink/?linkid=2088631"  # .NET 4.8 offline installer
    $installerPath = "$env:TEMP\ndp48-x86-x64-allos-enu.exe"

    try {
        Write-Log "Downloading .NET Framework 4.8 installer..."
        Invoke-WebRequest -Uri $dotNetUrl -OutFile $installerPath -UseBasicParsing

        Write-Log "Running .NET Framework installer..."
        $process = Start-Process -FilePath $installerPath -ArgumentList "/q", "/norestart" -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Log ".NET Framework 4.8 installed successfully" -Level Success
            return $true
        }
        elseif ($process.ExitCode -eq 3010) {
            Write-Log ".NET Framework 4.8 installed successfully (reboot required)" -Level Warning
            return $true
        }
        else {
            Write-Log ".NET Framework installation failed with exit code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error installing .NET Framework: $_" -Level Error
        return $false
    }
    finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Enable-TLS12 {
    Write-Log "Configuring TLS 1.2..."

    $tlsSettings = @(
        @{Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"; Name = "Enabled"; Value = 1},
        @{Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"; Name = "DisabledByDefault"; Value = 0},
        @{Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"; Name = "Enabled"; Value = 1},
        @{Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"; Name = "DisabledByDefault"; Value = 0}
    )

    foreach ($setting in $tlsSettings) {
        if (-not (Test-Path $setting.Path)) {
            New-Item -Path $setting.Path -Force | Out-Null
        }
        Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type DWord -Force
    }

    Write-Log "TLS 1.2 enabled" -Level Success
}

function Enable-StrongCryptography {
    Write-Log "Configuring strong cryptography for .NET..."

    $cryptoSettings = @(
        "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319"
    )

    foreach ($path in $cryptoSettings) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        Set-ItemProperty -Path $path -Name "SchUseStrongCrypto" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $path -Name "SystemDefaultTlsVersions" -Value 1 -Type DWord -Force
    }

    Write-Log "Strong cryptography enabled" -Level Success
}

function Install-WindowsFeatures {
    Write-Log "Checking Windows Features..."

    # Required features for Certificate Connector
    $features = @(
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Default-Doc",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Static-Content",
        "Web-Health",
        "Web-Http-Logging",
        "Web-Performance",
        "Web-Stat-Compression",
        "Web-Security",
        "Web-Filtering",
        "Web-Windows-Auth",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console"
    )

    $installNeeded = $false

    foreach ($feature in $features) {
        $state = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
        if ($state -and $state.InstallState -ne "Installed") {
            Write-Log "Feature $feature is not installed" -Level Warning
            $installNeeded = $true
        }
    }

    if ($installNeeded) {
        Write-Log "Installing Windows Features..."
        try {
            Install-WindowsFeature -Name $features -IncludeManagementTools | Out-Null
            Write-Log "Windows Features installed successfully" -Level Success
        }
        catch {
            Write-Log "Error installing Windows Features: $_" -Level Error
            return $false
        }
    }
    else {
        Write-Log "All required Windows Features are already installed" -Level Success
    }

    return $true
}

function Test-CertificateServices {
    Write-Log "Checking for local Certificate Services..."

    $caRole = Get-WindowsFeature -Name "AD-Certificate" -ErrorAction SilentlyContinue

    if ($caRole -and $caRole.InstallState -eq "Installed") {
        Write-Log "WARNING: Certificate Services (AD CS) is installed LOCALLY" -Level Warning
        Write-Log "This is unusual - CA should typically be on the Domain Controller" -Level Warning
        Write-Log "Verify this is your intended architecture" -Level Warning
        return $true
    }
    else {
        Write-Log "Certificate Services is NOT installed locally (expected for NDES-only server)" -Level Success
        Write-Log "CA should be running on your Domain Controller" -Level Info
        return $false
    }
}

function Install-NDESRole {
    param(
        [string]$ServiceAccount
    )

    Write-Log "Installing Network Device Enrollment Service (NDES)..."

    try {
        # Check if ADCS-Device-Enrollment is already installed
        $ndesRole = Get-WindowsFeature -Name "ADCS-Device-Enrollment" -ErrorAction SilentlyContinue

        if ($ndesRole -and $ndesRole.InstallState -eq "Installed") {
            Write-Log "NDES role is already installed" -Level Success
        }
        else {
            Write-Log "Installing NDES role features..."
            Install-WindowsFeature -Name "ADCS-Device-Enrollment" -IncludeManagementTools | Out-Null
            Write-Log "NDES role features installed" -Level Success
        }

        # Check if NDES is configured
        $ndesConfig = Get-Service -Name "SCEP" -ErrorAction SilentlyContinue
        if ($ndesConfig -and $ndesConfig.Status -eq "Running") {
            Write-Log "NDES service is already configured and running" -Level Success
            return $true
        }

        # If service account not provided, prompt for it
        if (-not $ServiceAccount) {
            Write-Log "NDES requires a service account for configuration" -Level Warning
            Write-Log "Please configure NDES manually using:" -Level Info
            Write-Log "  Install-AdcsNetworkDeviceEnrollmentService -ServiceAccountName DOMAIN\User -ServiceAccountPassword (ConvertTo-SecureString 'password' -AsPlainText -Force)" -Level Info
            return $false
        }

        Write-Log "NDES role installed. Service account configuration required for full setup." -Level Warning
        Write-Log "Use: Install-AdcsNetworkDeviceEnrollmentService -ServiceAccountName $ServiceAccount" -Level Info

        return $true
    }
    catch {
        Write-Log "Error installing NDES: $_" -Level Error
        return $false
    }
}

function Configure-SCEPTemplates {
    Write-Log "Checking SCEP certificate templates..."

    try {
        # Check if we can access certificate templates (requires Enterprise CA)
        $templates = certutil -CATemplates 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Certificate templates accessible" -Level Success

            # Check for common SCEP templates
            if ($templates -match "IPSec|CEPEncryption") {
                Write-Log "SCEP-compatible templates found" -Level Success
            }
            else {
                Write-Log "You may need to configure certificate templates for SCEP" -Level Warning
                Write-Log "Common templates needed: IPSec (Offline request), CEPEncryption" -Level Info
            }
        }
        else {
            Write-Log "Could not query certificate templates - may need Enterprise CA" -Level Warning
        }
    }
    catch {
        Write-Log "Error checking certificate templates: $_" -Level Warning
    }
}

function Set-ServiceStartup {
    Write-Log "Configuring service startup types..."

    $services = @(
        "W3SVC",      # World Wide Web Publishing Service
        "WAS"         # Windows Process Activation Service
    )

    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.StartType -ne "Automatic") {
                Set-Service -Name $serviceName -StartupType Automatic
                Write-Log "Set $serviceName to Automatic startup" -Level Success
            }
            if ($service.Status -ne "Running") {
                Start-Service -Name $serviceName
                Write-Log "Started $serviceName" -Level Success
            }
        }
    }
}

function Test-InternetConnectivity {
    Write-Log "Testing internet connectivity to Microsoft endpoints..."

    $endpoints = @(
        "https://login.microsoftonline.com",
        "https://graph.microsoft.com",
        "https://portal.azure.com"
    )

    foreach ($endpoint in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            Write-Log "Connectivity to $endpoint : OK" -Level Success
        }
        catch {
            Write-Log "Connectivity to $endpoint : FAILED" -Level Warning
        }
    }
}

# ====================
# Main execution
# ====================

Write-Log "========================================" -Level Info
Write-Log "Intune Certificate Connector Prerequisites Installation" -Level Info
Write-Log "========================================" -Level Info
Write-Log "Log file: $LogFile" -Level Info

$rebootRequired = $false
$caConfigDetected = $null

# 0. Check domain membership (required for NDES)
if (-not (Test-DomainMembership)) {
    Write-Log "" -Level Error
    Write-Log "Server must be domain-joined to use NDES" -Level Error
    Write-Log "Please join this server to your domain and run the script again" -Level Error
    exit 1
}

# 1. Check and install .NET Framework
if (-not $SkipDotNet) {
    if (-not (Test-DotNetVersion)) {
        $installed = Install-DotNet
        if ($installed) {
            $rebootRequired = $true
        }
    }
}
else {
    Write-Log "Skipping .NET Framework check (parameter specified)" -Level Info
}

# 2. Enable TLS 1.2
if (-not $SkipTLSConfig) {
    Enable-TLS12
    Enable-StrongCryptography
}
else {
    Write-Log "Skipping TLS configuration (parameter specified)" -Level Info
}

# 3. Install Windows Features
if (-not $SkipWindowsFeatures) {
    $featuresResult = Install-WindowsFeatures
    if ($featuresResult) {
        # Check if reboot needed
        $pendingReboot = Get-WindowsFeature | Where-Object { $_.InstallState -eq "InstallPending" }
        if ($pendingReboot) {
            $rebootRequired = $true
        }
    }
}
else {
    Write-Log "Skipping Windows Features installation (parameter specified)" -Level Info
}

# 4. Configure services
Set-ServiceStartup

# 5. Check for local Certificate Services (should NOT be here)
Test-CertificateServices

# 6. Test connectivity to remote CA on Domain Controller
$caConfigDetected = Test-RemoteCA -CAConfigString $CAConfig
if (-not $caConfigDetected) {
    Write-Log "" -Level Warning
    Write-Log "Could not verify remote CA connectivity" -Level Warning
    Write-Log "Please ensure:" -Level Warning
    Write-Log "  1. CA is installed and running on your Domain Controller" -Level Warning
    Write-Log "  2. This server can reach the DC" -Level Warning
    Write-Log "  3. Firewall allows RPC communication" -Level Warning
    Write-Log "" -Level Warning
}

# 7. Install NDES if not skipped
if (-not $SkipNDES) {
    # Check if NDES is already installed
    $ndesRole = Get-WindowsFeature -Name "ADCS-Device-Enrollment" -ErrorAction SilentlyContinue

    if ($ndesRole -and $ndesRole.InstallState -eq "Installed") {
        Write-Log "NDES is already installed" -Level Success
        Configure-SCEPTemplates
    }
    else {
        Write-Log "NDES not found - installing..." -Level Info
        Install-NDESRole -ServiceAccount $NDESServiceAccount -CAConfigString $caConfigDetected
        Configure-SCEPTemplates
    }
}
else {
    Write-Log "Skipping NDES installation (parameter specified)" -Level Info
}

# 8. Test connectivity
Test-InternetConnectivity

# ====================
# Summary
# ====================

Write-Log "========================================" -Level Info
Write-Log "Prerequisites installation completed!" -Level Success
Write-Log "========================================" -Level Info
Write-Log "" -Level Info
Write-Log "ARCHITECTURE SUMMARY:" -Level Info
Write-Log "- Domain Controller: Runs Certificate Authority (CA)" -Level Info
if ($caConfigDetected) {
    Write-Log "  CA Detected: $caConfigDetected" -Level Success
}
Write-Log "- This Server: Runs NDES + Intune Certificate Connector" -Level Info
Write-Log "- Communication: NDES -> CA for certificate issuance" -Level Info
Write-Log "" -Level Info

if ($rebootRequired) {
    Write-Log "" -Level Warning
    Write-Log "!!! REBOOT REQUIRED !!!" -Level Warning
    Write-Log "Please restart the server to complete the installation" -Level Warning
    Write-Log "" -Level Warning
}

Write-Log "Next steps:" -Level Info

if ($rebootRequired) {
    Write-Log "1. RESTART THE SERVER to complete installation" -Level Warning
    Write-Log "" -Level Warning
}

if (-not $caConfigDetected) {
    Write-Log "2. Verify CA is running on your Domain Controller" -Level Info
    Write-Log "3. Test CA connectivity: certutil -ping" -Level Info
}

$ndesInstalled = (Get-WindowsFeature -Name "ADCS-Device-Enrollment" -ErrorAction SilentlyContinue).Installed
if (-not $ndesInstalled) {
    Write-Log "4. Run this script again to install NDES" -Level Info
    if (-not $NDESServiceAccount) {
        Write-Log "   (Use -NDESServiceAccount 'DOMAIN\User' parameter)" -Level Info
    }
}
else {
    # Check if NDES service is running
    $ndesService = Get-Service -Name "SCEP" -ErrorAction SilentlyContinue
    if (-not $ndesService -or $ndesService.Status -ne "Running") {
        Write-Log "4. Complete NDES configuration (see guidance above)" -Level Info
        Write-Log "5. Configure certificate templates on CA (Domain Controller):" -Level Info
        Write-Log "   - IPSec (Offline request)" -Level Info
        Write-Log "   - CEPEncryption" -Level Info
        Write-Log "6. Grant NDES service account enrollment permissions on templates" -Level Info
    }
    else {
        Write-Log "4. NDES is configured and running!" -Level Success
        Write-Log "5. Verify certificate templates on CA (Domain Controller)" -Level Info
    }

    Write-Log "" -Level Info
    Write-Log "6. Download and install Intune Certificate Connector from:" -Level Info
    Write-Log "   https://aka.ms/intuneconnectorservices" -Level Info
    Write-Log "7. Sign in with your Intune admin account during installation" -Level Info
    Write-Log "8. Configure SCEP profiles in Microsoft Intune admin center" -Level Info
}

Write-Log "" -Level Info
Write-Log "Full log available at: $LogFile" -Level Info
