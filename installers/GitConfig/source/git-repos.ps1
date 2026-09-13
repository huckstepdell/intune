[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$UserName = "",

    [Parameter(Mandatory = $false)]
    [string]$UserEmail = ""
)

$ErrorActionPreference = 'Stop'
$logFolder = 'C:\Windows\Logs\Software'
$logFile = Join-Path -Path $logFolder -ChildPath 'GitConfig-install.log'

try {
    if (-not (Test-Path -LiteralPath $logFolder -PathType Container)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
}
catch {
    $logFile = Join-Path -Path $env:TEMP -ChildPath 'GitConfig-install.log'
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    try {
        $logLevel = switch ($Level) {
            'Info' { 1 }
            'Warning' { 2 }
            'Error' { 3 }
        }

        $component = Split-Path -Leaf $MyInvocation.ScriptName
        $time = Get-Date -Format 'HH:mm:ss.fff'
        $date = Get-Date -Format 'MM-dd-yyyy'
        $timeZoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
        $timeZoneString = '{0:+000;-000}' -f $timeZoneBias
        $logLine = "<![LOG[$Message]LOG]!><time=`"$time$timeZoneString`" date=`"$date`" component=`"$component`" context=`"`" type=`"$logLevel`" thread=`"$PID`" file=`"$component`">"

        $logLine | Out-File -FilePath $logFile -Append -Encoding utf8 -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Invoke-GitClone {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [string]$DestinationName
    )

    Write-Log "Cloning '$Repository' into '$DestinationName'."
    & git clone $Repository $DestinationName
    if ($LASTEXITCODE -ne 0) {
        throw "Git clone failed for '$Repository' with exit code $LASTEXITCODE."
    }

    Write-Log "Successfully cloned '$Repository'."
}

try {
    Write-Log "Starting Git configuration and repository installation for '$env:USERNAME'."
    $repositoriesPath = Join-Path -Path $HOME -ChildPath 'repos'
    New-Item -ItemType Directory -Path $repositoriesPath -Force | Out-Null
    Write-Log "Using repository path '$repositoriesPath'."

    git config --global user.name "$UserName"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure the Git user name with exit code $LASTEXITCODE."
    }

    git config --global user.email "$UserEmail"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure the Git user email with exit code $LASTEXITCODE."
    }

    git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure Git SSH with exit code $LASTEXITCODE."
    }
    Write-Log 'Git identity and SSH configuration completed.'

    Set-Location -Path $repositoriesPath
    Invoke-GitClone -Repository 'git@github.com:huckstepdell/intune.git' -DestinationName 'intune'
    Invoke-GitClone -Repository 'git@github.com:huckstepdell/lab.git' -DestinationName 'lab'
    Invoke-GitClone -Repository 'git@github.com:huckstepdell/mecm.git' -DestinationName 'mecm'
    Invoke-GitClone -Repository 'git@github.com:huckstep/homelab.git' -DestinationName 'homelab'
    Invoke-GitClone -Repository 'git@github.com:huckstep/docker_apps.git' -DestinationName 'docker_apps'
    Invoke-GitClone -Repository 'git@github.com:huckstepdell/wms.git' -DestinationName 'wms'
    Invoke-GitClone -Repository 'git@github.com:huckstepdell/deskside_ai.git' -DestinationName 'deskside_ai'

    Write-Log 'Repository cloning completed.'
    Write-Log 'Git configuration and repository installation completed successfully.'
}
catch {
    Write-Log "Git configuration and repository installation failed: $($_.Exception.Message)" -Level Error
    throw
}
