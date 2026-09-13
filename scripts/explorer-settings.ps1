# 1.0.1
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Create the key if it doesn't exist
If (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Show file extensions (0 = Show extensions, 1 = Hide extensions)
New-ItemProperty -Path $registryPath -Name "HideFileExt" -Value 0 -PropertyType DWORD -Force

# Show hidden files (1 = Show hidden files, 2 = Hide hidden files)
New-ItemProperty -Path $registryPath -Name "Hidden" -Value 1 -PropertyType DWORD -Force