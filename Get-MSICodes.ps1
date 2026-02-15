$searchPattern = Read-Host "Enter search pattern for application name (e.g., 'Dell', 'Microsoft', '*')"

Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
              "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" |
  ForEach-Object {
    Get-ItemProperty $_.PSPath
  } |
  Where-Object { $_.DisplayName -like "*$searchPattern*" } |
  Select-Object DisplayName, DisplayVersion, UninstallString, PSChildName, PSPath