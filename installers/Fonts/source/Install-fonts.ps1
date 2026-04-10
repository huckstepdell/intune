$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = "C:\Windows\Logs\Software"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "fonts.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    # Map log levels to CMTrace format: 1=Info, 2=Warning, 3=Error
    $logLevel = switch ($Level) {
        'Info'    { 1 }
        'Warning' { 2 }
        'Error'   { 3 }
        default   { 1 }
    }

    # Get caller info
    $component = Split-Path -Leaf $MyInvocation.ScriptName

    # Build timestamp in CMTrace format
    $time = Get-Date -Format "HH:mm:ss.fff"
    $date = Get-Date -Format "MM-dd-yyyy"
    $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
    $timeZoneString = "{0:+000;-000}" -f $timeZoneBias

    # Build CMTrace/OneTrace format log line
    $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

    # Write to log file
    $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# --- Main logic ---
try {
    Write-Log "=== Starting font installation ==="
    Write-Log "Script root: $PSScriptRoot"

    $fontsPath = "$env:WINDIR\Fonts"
    $regPath  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    Write-Log "Fonts destination: $fontsPath"
    Write-Log "Registry path: $regPath"

    # List all files in script directory for debugging
    Write-Log "Listing all files in script directory:"
    $allFiles = Get-ChildItem -Path $PSScriptRoot -File
    foreach ($file in $allFiles) {
        Write-Log "  Found file: $($file.Name) ($($file.Extension))"
    }

    # Dynamically find all .otf and .ttf files in the script directory
    Write-Log "Searching for .otf and .ttf files in $PSScriptRoot"
    $fontFiles = Get-ChildItem -Path "$PSScriptRoot\*" -Include "*.otf", "*.ttf" -File

    if (-not $fontFiles) {
        Write-Log "No font files found in script directory!" -Level Warning
        exit 0
    }

    Write-Log "Found $($fontFiles.Count) font file(s)"

    foreach ($fontFile in $fontFiles) {
        Write-Log "Processing font: $($fontFile.Name)"

        $source = $fontFile.FullName
        $dest   = Join-Path $fontsPath $fontFile.Name

        # Determine font type based on extension
        $fontType = if ($fontFile.Extension -eq ".otf") { "(OpenType)" } else { "(TrueType)" }
        Write-Log "  Font type: $fontType"

        # Create registry name from file name (remove extension and format)
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontFile.Name)
        $regName = "$fontName $fontType"
        Write-Log "  Registry name: $regName"

        # Copy font file if not already present
        if (-not (Test-Path $dest)) {
            Write-Log "  Copying font to: $dest"
            Copy-Item $source $dest -Force
            Write-Log "  Font copied successfully"
        }
        else {
            Write-Log "  Font already exists at destination, skipping copy"
        }

        # Register font in registry
        Write-Log "  Registering font in registry"
        New-ItemProperty -Path $regPath -Name $regName -Value $fontFile.Name -PropertyType String -Force | Out-Null
        Write-Log "  Font registered successfully"
    }

    Write-Log "=== Font installation completed successfully ==="
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
