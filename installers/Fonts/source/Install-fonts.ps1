$fontsPath = "$env:WINDIR\Fonts"
$regPath  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

$fontFiles = @(
    @{ File = "MyFont-Regular.ttf"; Name = "My Font (TrueType)" },
    @{ File = "MyFont-Bold.ttf";    Name = "My Font Bold (TrueType)" }
)

foreach ($font in $fontFiles) {
    $source = Join-Path $PSScriptRoot $font.File
    $dest   = Join-Path $fontsPath   $font.File

    if (-not (Test-Path $dest)) {
        Copy-Item $source $dest -Force
    }

    New-ItemProperty -Path $regPath -Name $font.Name -Value $font.File -PropertyType String -Force | Out-Null
}

exit 0
