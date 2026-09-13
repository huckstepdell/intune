<#[
.SYNOPSIS
    Detects the expected Git configuration for a Windows user.

.DESCRIPTION
    The script checks the user's profile-level .gitconfig file and verifies
    that all required repositories were cloned. It returns exit code 0 and
    writes to STDOUT only when the Git values and repositories match.

    Intune runs this script without command-line arguments. Set the default
    parameter values below before uploading the script to Intune, or provide
    values explicitly when testing it locally.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$WindowsUserName = 'REPLACE-WITH-WINDOWS-USERNAME',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GitUserName = 'REPLACE-WITH-GIT-USERNAME',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GitUserEmail = 'REPLACE-WITH-GIT-EMAIL',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$RequiredRepositories = @(
        'intune',
        'lab',
        'mecm',
        'homelab',
        'secrets',
        'docker_apps',
        'wms',
        'deskside_ai'
    )
)

$ErrorActionPreference = 'Stop'
$logFolder = 'C:\Windows\Logs\Software'
$logFile = Join-Path -Path $logFolder -ChildPath 'GitConfig-detect.log'

try {
    if (-not (Test-Path -LiteralPath $logFolder -PathType Container)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
}
catch {
    $logFile = Join-Path -Path $env:TEMP -ChildPath 'GitConfig-detect.log'
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

try {
    Write-Log "Starting Git configuration detection for Windows user '$WindowsUserName'."
    $usersRoot = Join-Path -Path $env:SystemDrive -ChildPath 'Users'
    $userProfilePath = Join-Path -Path $usersRoot -ChildPath $WindowsUserName
    $gitConfigPath = Join-Path -Path $userProfilePath -ChildPath '.gitconfig'
    $repositoriesPath = Join-Path -Path $userProfilePath -ChildPath 'repos'

    Write-Log "Checking Git config at '$gitConfigPath'."

    if (-not (Test-Path -LiteralPath $gitConfigPath -PathType Leaf)) {
        Write-Log 'Git config file was not found.' -Level Warning
        exit 1
    }

    $section = $null
    $gitValues = @{}

    foreach ($line in Get-Content -LiteralPath $gitConfigPath) {
        $trimmedLine = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmedLine) -or
            $trimmedLine.StartsWith(';') -or
            $trimmedLine.StartsWith('#')) {
            continue
        }

        if ($trimmedLine -match '^\[([^]]+)\]$') {
            $section = $matches[1].Trim().ToLowerInvariant()
            continue
        }

        if ($section -eq 'user' -and $trimmedLine -match '^([^=]+?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim().ToLowerInvariant()
            $gitValues[$key] = $matches[2].Trim()
        }
    }

    $nameMatches = $gitValues.ContainsKey('name') -and $gitValues['name'] -ceq $GitUserName
    $emailMatches = $gitValues.ContainsKey('email') -and $gitValues['email'] -ceq $GitUserEmail
    Write-Log "Git identity check: name match=$nameMatches, email match=$emailMatches."

    if ($nameMatches -and $emailMatches) {
        foreach ($repository in $RequiredRepositories) {
            $repositoryPath = Join-Path -Path $repositoriesPath -ChildPath $repository
            $gitDirectoryPath = Join-Path -Path $repositoryPath -ChildPath '.git'
            Write-Log "Checking repository '$repository' at '$gitDirectoryPath'."

            if (-not (Test-Path -LiteralPath $gitDirectoryPath -PathType Container)) {
                Write-Log "Repository '$repository' was not found or is not a Git clone." -Level Warning
                exit 1
            }
        }

        Write-Log "Detection succeeded for Windows user '$WindowsUserName'."
        Write-Output "Git configuration and repositories detected for $WindowsUserName"
        exit 0
    }

    Write-Log 'Detection failed because the Git identity did not match.' -Level Warning
    exit 1
}
catch {
    Write-Log "Detection failed with an error: $($_.Exception.Message)" -Level Error
    exit 1
}