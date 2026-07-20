# Install-WindowsAutopilotInfo.ps1
# Run in an elevated PowerShell session

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

if ((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
}

if (Get-InstalledScript -Name Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue) {
    Update-Script -Name Get-WindowsAutopilotInfo -Force
}
else {
    Install-Script -Name Get-WindowsAutopilotInfo -Force
}

Write-Host "Get-WindowsAutopilotInfo is installed and ready." -ForegroundColor Green
Write-Host ""
Write-Host "Examples:"
Write-Host "Export hash to CSV:"
Write-Host "  Get-WindowsAutopilotInfo -OutputFile C:\HWID.csv"
Write-Host ""
Write-Host "Upload directly to Intune:"
Write-Host "  Get-WindowsAutopilotInfo -Online"
Write-Host ""
Write-Host "Upload and wait for profile assignment during OOBE:"
Write-Host "  Get-WindowsAutopilotInfo -Online -Assign"
