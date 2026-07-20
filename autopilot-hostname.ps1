# Get the device Serial Number
$Serial = (Get-CimInstance Win32_BIOS).SerialNumber.Replace(" ","")

# Get the Windows OS Build Number
$OSBuild = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber

# Check if OS is Windows 11 (Build 22000 or higher)
if ($OSBuild -ge 22000) {
    $Prefix = "W11-"
} else {
    $Prefix = "W10-" # Optional: Fallback prefix for Windows 10
}

# Combine and trim to max 15 characters for NetBIOS compliance
$NewName = "$Prefix$Serial"
if ($NewName.Length -gt 15) { $NewName = $NewName.Substring(0,15) }

# Get Current Name
$CurrentName = $env:COMPUTERNAME

# Rename computer if it doesn't already match
if ($CurrentName -ne $NewName) {
    Rename-Computer -NewName $NewName -Force -ErrorAction SilentlyContinue

    # Schedule a reboot immediately for Intune to catch the change
    Restart-Computer -Force
}
