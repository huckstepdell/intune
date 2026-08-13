$clsid = '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}'

$paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu'
)

foreach ($path in $paths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    New-ItemProperty -Path $path -Name $clsid -PropertyType DWord -Value 1 -Force | Out-Null
}
