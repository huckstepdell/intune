[CmdletBinding()]
param(
    [Version]$RequiredVersion = [Version]'0.6.2'
)

$ErrorActionPreference = 'Stop'

$registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

try {
    $installedApps = foreach ($registryPath in $registryPaths) {
        Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -like '*Phaze*' -and
                $_.DisplayVersion
            }
    }

    foreach ($app in $installedApps) {
        $installedVersion = $null
        if ([Version]::TryParse($app.DisplayVersion, [ref]$installedVersion) -and
            $installedVersion -ge $RequiredVersion) {
            Write-Output 'Detected'
            exit 0
        }
    }
}
catch {
    exit 1
}

exit 1