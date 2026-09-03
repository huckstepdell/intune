# 1. Windows 11 Power Mode Overlays (Slider)
$overlayPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
$perfGuid = "ded574b5-45a0-4f42-8737-46345c09c238"
$effGuid = "961cc777-2547-4f9d-8174-7d86181b8a7a"

Set-ItemProperty -Path $overlayPath -Name ActiveOverlayAcPowerScheme -Value $perfGuid -Force
Set-ItemProperty -Path $overlayPath -Name ActiveOverlayDcPowerScheme -Value $effGuid -Force

# 2. Base Power Plan Settings
$activePlan = (Get-ItemProperty -Path $overlayPath).ActivePowerScheme
$sleepGroup = "238c9fa8-0aad-41ed-83f4-97be242c8f20"
$videoGroup = "7516b95f-f776-4464-8c53-06167f40cc99"

# Disable Sleep on AC (0 seconds)
Set-ItemProperty -Path "$overlayPath\$activePlan\$sleepGroup\29f6c1db-86da-48c5-9fdb-f2b67b1f44da" -Name "ACSettingIndex" -Value 0 -Force

# Disable Hibernate on AC (0 seconds)
Set-ItemProperty -Path "$overlayPath\$activePlan\$sleepGroup\9d7815a6-7ee4-497e-8888-515a05f02364" -Name "ACSettingIndex" -Value 0 -Force

# Sleep Display on AC after 10 minutes (600 seconds)
Set-ItemProperty -Path "$overlayPath\$activePlan\$videoGroup\3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" -Name "ACSettingIndex" -Value 600 -Force

# Turn off Hibernate feature globally
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Value 0 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabledDefault" -Value 0 -Force

# 3. Apply changes immediately via PowrProf.dll API (100% powercfg-free refresh)
$signature = '[DllImport("powrprof.dll")] public static extern uint PowerSetActiveScheme(IntPtr UserRootPowerKey, ref Guid SchemeGuid);'
$powerAPI = Add-Type -MemberDefinition $signature -Name "PowerAPI" -Namespace "Win32" -PassThru
$planGuid = [guid]$activePlan
$powerAPI::PowerSetActiveScheme([IntPtr]::Zero, [ref]$planGuid) | Out-Null