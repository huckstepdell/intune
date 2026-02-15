function Get-WingetPath {
    # 1) Prefer DesktopAppInstaller x64 folder in Program Files\WindowsApps
    $windowsApps = "C:\Program Files\WindowsApps"
    if (Test-Path $windowsApps) {
        $candidate = Get-ChildItem -Path $windowsApps -Directory -Filter "Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending |
                     Select-Object -First 1

        if ($candidate) {
            $possibleWinget = Join-Path $candidate.FullName "winget.exe"
            if (Test-Path $possibleWinget) {
                return $possibleWinget
            }
        }
    }

    # 2) Fallback: PATH
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}