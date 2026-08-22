<#
.SYNOPSIS
    Creates a default Python virtual environment for the current user

.DESCRIPTION
    Requires the Python Install Manager (py.exe) to already be present - it's a
    Store app and can't be pushed as an Intune dependency, so this script just
    verifies it works (py help), has it install Python 3 (py install 3), then
    creates a venv at $HOME\venvs\default and installs/upgrades $DefaultPackages
    (e.g. ansible-lint) into it. Idempotent - safe to re-run; existing venvs are
    reused and packages are just upgraded in place.

.NOTES
    This app must be deployed as a User-context Win32 app in Intune (not System),
    since $HOME needs to resolve to the logged-on user's profile.
    Logs to: $env:LOCALAPPDATA\Logs\Software\PythonVenv-install.log
#>

[CmdletBinding()]
Param(
    # Packages installed/upgraded into the venv every run, so updates are picked up too
    [string[]]$DefaultPackages = @('ansible-lint')
)

$ErrorActionPreference = "Stop"

# --- Logging setup ---
$LogFolder = Join-Path $env:LOCALAPPDATA "Logs\Software"
try {
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $LogFile = Join-Path $LogFolder "PythonVenv-install.log"
}
catch {
    $LogFolder = $env:TEMP
    $LogFile = Join-Path $LogFolder "PythonVenv-install.log"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $logLevel = switch ($Level) {
        'Info'    { 1 }
        'Warning' { 2 }
        'Error'   { 3 }
        default   { 1 }
    }

    $component = Split-Path -Leaf $MyInvocation.ScriptName
    $time = Get-Date -Format "HH:mm:ss.fff"
    $date = Get-Date -Format "MM-dd-yyyy"
    $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
    $timeZoneString = "{0:+000;-000}" -f $timeZoneBias

    $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

    try {
        $logLine | Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction Stop
    }
    catch {
        # Silently ignore logging errors
    }
}

function Test-PyInstallManager {
    # The Python Install Manager (Store app) only counts as present if 'py help' actually runs
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $py) {
        return $false
    }

    $process = Start-Process -FilePath $py.Source -ArgumentList @('help') -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $env:TEMP 'py-help-out.txt') -RedirectStandardError (Join-Path $env:TEMP 'py-help-err.txt')
    return ($process.ExitCode -eq 0)
}

# --- Main logic ---
try {
    Write-Log "=== Starting Python venv installation ==="

    $venvRoot = Join-Path $HOME "venvs"
    $venvPath = Join-Path $venvRoot "default"
    $venvPython = Join-Path $venvPath "Scripts\python.exe"

    Write-Log "Target venv path: $venvPath"

    Write-Log "Checking Python Install Manager (py help)"
    if (-not (Test-PyInstallManager)) {
        Write-Log "'py help' failed or py.exe not found - Python Install Manager is not available" -Level Error
        throw "Python Install Manager (py.exe) is not installed or not working"
    }
    Write-Log "Python Install Manager is available"

    if (Test-Path $venvPython) {
        Write-Log "Venv already exists at $venvPath"
    }
    else {
        Write-Log "Ensuring Python 3 is installed (py install 3)"
        $installProcess = Start-Process -FilePath "py.exe" -ArgumentList @('install', '3') -Wait -PassThru -NoNewWindow
        if ($installProcess.ExitCode -ne 0) {
            Write-Log "'py install 3' exited with code $($installProcess.ExitCode)" -Level Error
            throw "py install 3 failed with exit code $($installProcess.ExitCode)"
        }

        if (-not (Test-Path $venvRoot)) {
            Write-Log "Creating venvs folder: $venvRoot"
            New-Item -Path $venvRoot -ItemType Directory -Force | Out-Null
        }

        Write-Log "Creating virtual environment at: $venvPath"
        $process = Start-Process -FilePath "py.exe" -ArgumentList @('-3', '-m', 'venv', $venvPath) -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -ne 0) {
            Write-Log "venv creation exited with code $($process.ExitCode)" -Level Error
            throw "py -3 -m venv failed with exit code $($process.ExitCode)"
        }

        if (-not (Test-Path $venvPython)) {
            Write-Log "venv python.exe not found after creation: $venvPython" -Level Error
            throw "Virtual environment creation did not produce expected files"
        }
    }

    if ($DefaultPackages.Count -gt 0) {
        Write-Log "Installing default packages: $($DefaultPackages -join ', ')"
        $pipArgs = @('-m', 'pip', 'install', '--upgrade') + $DefaultPackages
        $pipProcess = Start-Process -FilePath $venvPython -ArgumentList $pipArgs -Wait -PassThru -NoNewWindow

        if ($pipProcess.ExitCode -ne 0) {
            Write-Log "pip install exited with code $($pipProcess.ExitCode)" -Level Error
            throw "Installing default packages failed with exit code $($pipProcess.ExitCode)"
        }

        Write-Log "Default packages installed successfully"
    }

    Write-Log "=== Python venv installation completed successfully ==="
    exit 0
}
catch {
    Write-Log "Installation failed: $($_.Exception.Message)" -Level Error
    exit 1
}
