<#
_author_ = Sven Riebe <sven_riebe@Dell.com>
_twitter_ = @SvenRiebe
_version_ = 1.0.1
_Dev_Status_ = Test
Copyright ©2026 Dell Inc. or its subsidiaries. All Rights Reserved.

No implied support and test in test environment/device before using in any production environment.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

<#
.Synopsis
   This PowerShell is for uninstall Dell tools by Name and in Microsoft Intune or other solutions like this.

.DESCRIPTION
   This PowerShell will check if the requested Dell Software is installed and uninstall it.
   This script support the following applications
        - Dell Core Services
        - Dell SupportAssist
        - Dell SupportAssist Remediation
        - Dell SupportAssist OS Recovery
        - Dell Display and Peripheral Manager
        - Dell Device Management Agent (Agent for Dell Device Management Console for Peripherals updates)
        - Dell Command | Update (Universal App and Classic)
        - Dell Command | Configure
        - Dell Command | Endpoint Configure for Microsoft Intune
        - Dell Command | Monitor
        - Dell Trusted Device
        - Dell Optimizer
        - Dell Pair
        - Dell Digital Delivery
        - Dell Peripheral Core
        - Microsoft Windows Desktop Runtime 6, 8, 9 and 10 (because some Dell tools require this as preparation) becareful it is not used by other applications
        - Microsoft ASP.Net Core Runtime 6, 8, 9 and 10 (because some Dell tools require this as preparation) becareful it is not used by other applications

        .Parameter DellTool
        Value is the Name of Dell Application to looking for like example Dell Trusted Device


        Changelog:
            1.0.0   Initial Version
            1.0.1   Fixing uninstall issue with empty uninstallstring on Dell Device Management Agent
                    Fixing problem with silent parameter for Dell SupportAssist Remediation
                    Fixing issue with Dell Digital where older versions are found by registry but not exist as application
                    Enhancements:
                        - Add Timer for sticky uninstall processes at 5min
                        - checking elevated rights before start with uninstall process

        .Example
        This will looking if Dell Command | Update is installed and uninstall this software
        UniversialDellUninstall.ps1 -DellTool 'Dell Command | Update'

        .Example
        This will looking for all listed Dell tools and uninstall them
        UniversialDellUninstall.ps1 -DellTool 'AllDell'

        .Example
        This will looking for Microsoft Desktop Runtime 8 and uninstall this software
        UniversialDellUninstall.ps1 -DellTool 'Microsoft Windows Desktop Runtime 8'

#>
param(
            [Parameter(mandatory=$false)][ValidateSet("AllDell","Dell Core Services","Dell Device Management Agent","Dell Digital Delivery","Dell Peripheral Core","Dell SupportAssist","Dell SupportAssist Remediation","Dell SupportAssist OS Recovery Plugin for Dell Update","Dell Display and Peripheral Manager","Dell Command | Update","Dell Command | Configure","Dell Command | Endpoint Configure for Microsoft Intune","Dell Command | Monitor","Dell Trusted Device","Dell Optimizer","Dell Pair","Microsoft Windows Desktop Runtime 6","Microsoft Windows Desktop Runtime 8","Microsoft Windows Desktop Runtime 9","Microsoft Windows Desktop Runtime 10","Microsoft ASP.Net Core Runtime 6","Microsoft ASP.Net Core Runtime 8","Microsoft ASP.Net Core Runtime 9","Microsoft ASP.Net Core Runtime 10")][String]$DellTool
    )

# Fallback if parameters are not provided by script call

##################################################
# Varible Section                            #####
##################################################
$DellSoftwareList = @(
                        [PSCustomObject]@{NameParameter = "Dell SupportAssist OS Recovery Plugin for Dell Update"; SearchString = "Dell*SupportAssist*OS*Recovery*Plugin*"; SetupSearchString = "Dell*SupportAssist*OS*Recovery*Plugin*"; SilentSwitch = "/uninstall /quiet"; Sequence = 2; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Core Services"; SearchString = "Dell*Core*Services"; SetupSearchString = "Dell*Core*Services"; SilentSwitch = "/qn"; Sequence = 3; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell SupportAssist"; SearchString = "Dell*Supportassist"; SetupSearchString = "SupportAssist*"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = "ADDLOCAL='BASE,CORE,FULL,HWDIAGS,INSIGHTS,RAAS' SOURCE=TechDirect /norestart /qn"}
                        [PSCustomObject]@{NameParameter = "Dell SupportAssist Remediation"; SearchString = "Dell*Supportassist*Remediation"; SetupSearchString = "SupportAssist*"; SilentSwitch = "/uninstall /quiet"; Sequence = 3; Type = "EXE"; InstallSwitch = "ADDLOCAL='BASE,CORE,FULL,HWDIAGS,INSIGHTS,RAAS' SOURCE=TechDirect /norestart /qn"}
                        [PSCustomObject]@{NameParameter = "Dell Display and Peripheral Manager"; SearchString = "Dell*Display*Peripheral*Manager"; SetupSearchString = "DDPM-Setup*"; SilentSwitch = "-runfromtemp -removeonly /uninst /silent"; Sequence = 1; Type = "EXE"; InstallSwitch = "/Silent /InAppUpdateLock /TelemetryConsent=false"}
                        [PSCustomObject]@{NameParameter = "Dell Device Management Agent"; SearchString = "Dell*Device*Management*Agent"; SetupSearchString = "DellDeviceManagementAgent.SubAgent*"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = '/s /v"/qn GROUPTOKEN="{0}" URL="https://device.manage.dell.com" /lv* C:\ProgramData\Dell\DDMA_installer.log"' -f $DCDMGROUPTOKEN}
                        [PSCustomObject]@{NameParameter = "Dell Command | Update"; SearchString = "Dell*Command*Update*"; SetupSearchString = "Dell*Command*Update*"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Command | Configure"; SearchString = "Dell*Command*Configure"; SetupSearchString = "Dell*Command*Configure"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Command | Endpoint Configure for Microsoft Intune"; SetupSearchString = "Dell-Command-Endpoint*"; SearchString = "Dell*Command*Endpoint*Configure*Intune"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Command | Monitor"; SearchString = "Dell*Command*Monitor"; SetupSearchString = "Dell*Command*Monitor"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Trusted Device"; SearchString = "Dell*Trusted*Device"; SetupSearchString = "Dell*Trusted*Device"; SilentSwitch = "/qn"; Sequence = 1; Type = "EXE"; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Optimizer"; SearchString = "Dell*Optimizer"; SetupSearchString = "Dell*Optimizer"; SilentSwitch = "-remove -runfromtemp /Silent"; Sequence = 1; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Pair"; SearchString = "Dell*Pair"; SetupSearchString = "Dell*Pair"; SilentSwitch = "/S"; Sequence = 2; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Peripheral Core"; SearchString = "Dell*Peripheral*Core"; SetupSearchString = "Dell*Peripheral*Core"; SilentSwitch = "/S"; Sequence = 3; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Dell Digital Delivery"; SearchString = "Dell*Digital*Delivery*Services"; SetupSearchString = "Dell*Digital*Delivery*"; SilentSwitch = "/qn"; Sequence = 2; InstallSwitch = "/S"}
                        [PSCustomObject]@{NameParameter = "Microsoft Windows Desktop Runtime 6"; SearchString = "Microsoft*Windows*Desktop*Runtime*6*(x64)*"; SetupSearchString = "windowsdesktop-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft Windows Desktop Runtime 8"; SearchString = "Microsoft*Windows*Desktop*Runtime*8*(x64)*"; SetupSearchString = "windowsdesktop-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft Windows Desktop Runtime 9"; SearchString = "Microsoft*Windows*Desktop*Runtime*9*(x64)*"; SetupSearchString = "windowsdesktop-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft Windows Desktop Runtime 10"; SearchString = "Microsoft*Windows*Desktop*Runtime*10*(x64)*"; SetupSearchString = "windowsdesktop-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft ASP.Net Core Runtime 6"; SearchString = "Microsoft*ASP.Net*Core*6*(x64)*"; SetupSearchString = "aspnetcore-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft ASP.Net Core Runtime 8"; SearchString = "Microsoft*ASP.Net*Core*8*(x64)*"; SetupSearchString = "aspnetcore-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft ASP.Net Core Runtime 9"; SearchString = "Microsoft*ASP.Net*Core*9*(x64)*"; SetupSearchString = "aspnetcore-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                        [PSCustomObject]@{NameParameter = "Microsoft ASP.Net Core Runtime 10"; SearchString = "Microsoft*ASP.Net*Core*10*(x64)*"; SetupSearchString = "aspnetcore-runtime*"; SilentSwitch = "/uninstall /quiet /norestart"; Sequence = 9; InstallSwitch = "/install /quiet /norestart"}
                    )

##################################################
# Function Section                           #####
##################################################
function Test-SoftwareInstalled
    {
        param(
                    [Parameter(mandatory=$false)][string]$NamePattern,
                    [Parameter(mandatory=$false)][ValidateSet("Equal","Not equal","Less than","Less than or equal","Greater than","Greater than or equal")][String]$ISPattern,
                    [Parameter(mandatory=$false)][Version]$VersionPattern
            )

        # Uninstall-Path (64-bit & 32-bit)
        $paths = @(
                    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )


        # cover name conversion of Dell SupportAssist for Business PCs to Dell SupportAssist.
        if($NamePattern -eq "Dell Supportassist" -and [Version]$VersionPattern -lt "5.0")
            {
                $NamePattern = "Dell Supportassist*Business*PCs"
            }

        $items = foreach ($path in $paths)
            {
                try
                    {
                        If ($NamePattern -notmatch "Microsoft.*Windows.*Desktop.*Runtime.*(x64).*" -and $NamePattern -notmatch "Microsoft.*ASP.Net.*Core.*(x64).*")
                            {
                                Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like $NamePattern}
                            }
                        else
                            {
                                If ($path -like $paths[1])
                                    {
                                        # try to cover wrong .net Version seen with some installer
                                        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like $NamePattern -and ([version]$_.DisplayVersion).Major -eq $VersionPattern.Major }
                                    }
                            }
                    }
                catch
                    {
                        Write-Output "Path no found" | Out-Null
                    }
            }

        #Checking be different operators if displayversion match
        if($ISPattern -eq "Equal")
            {
                $match = $items | Where-Object {[version]$_.DisplayVersion -eq [version]$VersionPattern}
            }
        elseif($ISPattern -eq "Not equal")
            {
                $match = $items | Where-Object {[version]$_.DisplayVersion -ne [version]$VersionPattern}
            }
        elseif($ISPattern -eq "Less than")
            {
                $match = $items | Where-Object {[version]$_.DisplayVersion -lt [version]$VersionPattern}
            }
        elseif($ISPattern -eq "Less than or equal")
            {
                $match = $items | Where-Object {[version]$_.DisplayVersion -le [version]$VersionPattern}
            }
        elseif($ISPattern -eq "Greater than")
            {
                $match = $items | Where-Object {[version]$_.DisplayVersion -gt [version]$VersionPattern}
            }
        elseif($ISPattern -eq "Greater than or equal")
            {
                $match = $items | Where-Object {[version]$_.DisplayVersion -ge [version]$VersionPattern}
            }

        return $match
    }

function Uninstall-DellTool
    {
        param
            (
                [Parameter(Mandatory)][string]$NamePattern,
                [Parameter(Mandatory)][string]$AppID,
                [Parameter(Mandatory)][string]$UninstallString
            )

        # Uninstall by MSI
        if ($UninstallString -like "*msiexec*")
            {
                try
                    {
                        #start Uninstall with timeout trigger
                        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $AppID /qn /norestart" -PassThru

                        if (-not $process.WaitForExit(300000))
                            {
                                Write-Warning "Timeout uninstall $NamePattern after 5 minutes"
                                Stop-Process -Id $process.Id -Force
                            }

                        If($NamePattern -eq "Dell Digital Delivery")
                            {
                                Get-AppxPackage -AllUsers -Name "DellInc.DellDigitalDelivery" | Remove-AppxPackage
                                Write-Verbose "Uninstalled APPX DellInc.DellDigitalDelivery successfull" -Verbose
                            }

                        Return $true
                    }
                catch
                    {
                        Write-Verbose "Failed to uninstall $NamePattern" -Verbose
                        Return $false
                    }
            }
        # Uninstall by executable
        elseif ($null -ne $UninstallString)
            {
                try
                    {
                        # select the searchstring for function
                        $Software = $DellSoftwareList | where-object {$_.NameParameter -eq $NamePattern}

                        #Build up uninstall parameters based on Uninstallstring on registry
                        if ($UninstallString -match '^"([^"]+\.exe)"')
                            {
                                $UninstallEXE = $Matches[1]
                            }
                        
                        # prepare uninstall string
                        $ArgumentString = $Software.SilentSwitch

                        #start Uninstall with timeout trigger
                        Start-Process -FilePath $UninstallEXE -ArgumentList $ArgumentString -NoNewWindow -PassThru

                        # Build a timer to avoid start-process stucks on -wait because of not closed windows
                        $CheckRegKey = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern 0.0.0.0 -ISPattern "Greater than"
                        $MaxWaitTime = 300# 5 minutes
                        $timer = 0

                        while ($null -ne $CheckRegKey -and $timer -lt $MaxWaitTime) 
                            {
                                If($null -ne $CheckRegKey)
                                    {
                                        # add 1 sec to the timer
                                        Start-Sleep -Seconds 5
                                        $timer = $timer + 5

                                        If($timer -ge $MaxWaitTime)
                                            {
                                                Write-Warning "Uninstall $NamePattern takes more than 5 minutes"
                                            }
                                    }
                                
                                # Check if the uninstall regkey still exist.
                                $CheckRegKey = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern 0.0.0.0 -ISPattern "Greater than"
                            }
                  
                        # temp postone the script to take care all actions are closed
                        Start-Sleep -Seconds 5
                            
                        Return $true
                    }
                catch
                    {
                        Write-Verbose "Failed to uninstall $NamePattern" -Verbose
                        Return $false
                    }
            }
        else
            {
                Write-Verbose "No uninstall string found for $NamePattern" -Verbose
                Return $false
            }
    }

function Test-ElevatedContext
    {
        param()

        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)

        $isAdmin = $principal.IsInRole(
            [System.Security.Principal.WindowsBuiltInRole]::Administrator
        )

        $isSystem = $identity.User.Value -eq "S-1-5-18"

        return @{
            IsAdmin  = $isAdmin
            IsSystem = $isSystem
            IsElevated = $isAdmin -or $isSystem
            UserName = $identity.Name
        }
    }
##################################################
# Program Section                            #####
##################################################

#### Checking if script have elevated rights
try
    {
        $ElevatedStatus = Test-ElevatedContext

        if ($ElevatedStatus.IsElevated -ne $true) 
            {
                Write-Warning "Console is not running in elevated rights"

                $UninstallData = [PSCustomObject]@{
                                                        Software = $($SoftwareInst.DisplayName)
                                                        Version = $($SoftwareInst.DisplayVersion)
                                                        Uninstall = "Console have no elevated rights"
                                                    } | ConvertTo-Json

                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Error -EventId 12 -Message $UninstallData
                Exit 1
            }
    }
catch
    {
        Write-Output "Script failed: $($_.Exception.Message)"
        Exit 1
    }

#### generate Logging Resources
try
    {
        [System.Diagnostics.EventLog]::CreateEventSource("Dell Software Uninstall", "Dell")
        Write-Verbose "Event source Dell Software Uninstall created for log Dell." -Verbose
    }
catch
    {
        Write-Verbose "Event source Dell Software Uninstall exist." -Verbose
    }

#### Check if installed and if yes uninstall application
Try
    {
        If($DellTool -ne "AllDell")
            {
                # select the searchstring for function
                $Software = $DellSoftwareList | where-object {$_.NameParameter -eq $DellTool}

                #### get Software details
                $Versioncheck = switch ($DellTool)
                    {
                        "Microsoft ASP.Net Core Runtime 10" {[Version]"10.0.0.0"}
                        "Microsoft ASP.Net Core Runtime 9" {[Version]"9.0.0.0"}
                        "Microsoft ASP.Net Core Runtime 8" {[Version]"8.0.0.0"}
                        "Microsoft ASP.Net Core Runtime 6" {[Version]"6.0.0.0"}
                        "Microsoft Windows Desktop Runtime 10" {[Version]"10.0.0.0"}
                        "Microsoft Windows Desktop Runtime 9" {[Version]"9.0.0.0"}
                        "Microsoft Windows Desktop Runtime 8" {[Version]"8.0.0.0"}
                        "Microsoft Windows Desktop Runtime 6" {[Version]"6.0.0.0"}

                        Default {[Version]"0.0.0.0"}
                    }

                $SoftwareDetails = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern $Versioncheck -ISPattern "Greater than"

                # cleanup App list for non msi uninstall apps like Dell Optimizer
                if ($Software.NameParameter -eq "Dell Optimizer" -or $Software.NameParameter -eq "Dell SupportAssist OS Recovery Plugin for Dell Update" -or $Software.NameParameter -eq "Dell SupportAssist Remediation" -or $Software.NameParameter -like "Microsoft Windows Desktop Runtime*")
                    {
                        $SoftwareDetails = $SoftwareDetails | Where-Object {$Null -eq $_.InstallLocation}
                    }

                # cover registry are missing uninstallstring
                if($null -eq $SoftwareDetails.uninstallstring)
                    {
                        $SoftwareDetails | Add-Member NoteProperty -Name UninstallString -Value "msiexec"
                    }

                #cover multiversions like you will have at .net installations
                Foreach ($SoftwareInst in $SoftwareDetails)
                    {
                        # cover uninstall string not exist. This will be automaticlly a msi uninstall by default
                        try
                            {
                                $SoftwareInst.UninstallString = $SoftwareInst.UninstallString #create a issue if not exist
                            }
                        catch
                            {
                                $SoftwareInst | Add-Member -MemberType NoteProperty -Name "UninstallString" -Value "msiexec"
                            }

                        if($null -ne $SoftwareInst)
                            {
                                Write-Verbose "$($SoftwareInst.DisplayName) is installed with version $($SoftwareInst.DisplayVersion)" -Verbose
                                $UninstallData = [PSCustomObject]@{
                                                                    Software = $($SoftwareInst.DisplayName)
                                                                    Version = $($SoftwareInst.DisplayVersion)
                                                                    Uninstall = "started now"
                                                                } | ConvertTo-Json

                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData

                                if ($DellTool -notlike "Microsoft Windows Desktop Runtime*" -and $DellTool -notlike "Microsoft ASP.NET Core Runtime*")
                                    {
                                        # call uninstall function with cover multiple uninstall strings
                                        Uninstall-DellTool -NamePattern $Software.NameParameter -AppID $SoftwareInst.PSChildName -UninstallString $SoftwareInst.UninstallString | Out-Null

                                        # Logging uninstall result
                                        $UninstallResult = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern 0.0.0.0 -ISPattern "Greater than"

                                        If($null -eq $UninstallResult)
                                            {
                                                Write-Verbose "$DellTool is uninstalled successfully" -Verbose

                                                $UninstallData = [PSCustomObject]@{
                                                                                    Software = $DellTool
                                                                                    Version = $($SoftwareDetails.DisplayVersion)
                                                                                    Uninstall = $true
                                                                                } | ConvertTo-Json

                                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                                                Exit 0
                                            }
                                        else
                                            {
                                                Write-Verbose "$DellTool uninstall failed" -Verbose

                                                $UninstallData = [PSCustomObject]@{
                                                                                    Software = $DellTool
                                                                                    Version = $($SoftwareDetails.DisplayVersion)
                                                                                    Uninstall = $false
                                                                                } | ConvertTo-Json

                                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                                                Exit 1
                                            }
                                    }
                                else
                                    {

                                        # call uninstall function with cover multiple uninstall strings
                                        Uninstall-DellTool -NamePattern $Software.NameParameter -AppID $SoftwareInst.PSChildName -UninstallString $SoftwareInst.UninstallString | Out-Null

                                        # Check if Application uninstall was successful
                                        $UninstallResult = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern $SoftwareInst.DisplayVersion -ISPattern Equal

                                        If($null -eq $UninstallResult)
                                            {
                                                Write-Verbose "$DellTool is uninstalled successfully" -Verbose

                                                $UninstallData = [PSCustomObject]@{
                                                                                    Software = $DellTool
                                                                                    Version = $($SoftwareInst.DisplayVersion)
                                                                                    Uninstall = $true
                                                                                } | ConvertTo-Json

                                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                                            }
                                        else
                                            {
                                                Write-Verbose "$DellTool uninstall failed" -Verbose

                                                $UninstallData = [PSCustomObject]@{
                                                                                    Software = $DellTool
                                                                                    Version = $($SoftwareInst.DisplayVersion)
                                                                                    Uninstall = $false
                                                                                } | ConvertTo-Json

                                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                                            }

                                    }

                            }
                        else
                            {
                                Write-Verbose "$DellTool is not installed script will exit here" -Verbose

                                $UninstallData = [PSCustomObject]@{
                                                                    Software = $DellTool
                                                                    Version = "not installed"
                                                                    Uninstall = $true
                                                                } | ConvertTo-Json

                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                                Exit 0
                            }
                    }
            }
        else
            {
                # build uninstall working list by sequence number
                $DellSoftwareList = $DellSoftwareList | Where-Object {$_.Sequence -ne 9}  | Sort-Object -Property Sequence

                Foreach ($Software in $DellSoftwareList)
                    {
                        #### get Software details
                        $SoftwareDetails = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern 0.0.0.0 -ISPattern "Greater than"

                        # cleanup App list for non msi uninstall apps like Dell Optimizer
                        if ($Software.NameParameter -eq "Dell Optimizer" -or $Software.NameParameter -eq "Dell SupportAssist OS Recovery Plugin for Dell Update" -or $Software.NameParameter -eq "Dell SupportAssist Remediation")
                            {
                                $SoftwareDetails = $SoftwareDetails | Where-Object {$Null -eq $_.InstallLocation}
                            }

                        # cover registry are missing uninstallstring
                        if($null -eq $SoftwareDetails.uninstallstring)
                            {
                                $SoftwareDetails | Add-Member NoteProperty -Name UninstallString -Value "msiexec"
                            }

                        if($null -ne $SoftwareDetails)
                            {
                                Write-Verbose "$($SoftwareDetails.DisplayName) is installed with version $($SoftwareDetails.DisplayVersion)" -Verbose
                                $UninstallData = [PSCustomObject]@{
                                                                        Software = $($SoftwareDetails.DisplayName)
                                                                        Version = $($SoftwareDetails.DisplayVersion)
                                                                        Uninstall = "started now"
                                                                } | ConvertTo-Json

                                Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData

                                # call uninstall function with cover multiple uninstall strings
                                Uninstall-DellTool -NamePattern $Software.NameParameter -AppID $SoftwareDetails.PSChildName -UninstallString $SoftwareDetails.UninstallString |Out-Null

                                # Logging uninstall result
                                $UninstallResult = Test-SoftwareInstalled -NamePattern $Software.SearchString -VersionPattern 0.0.0.0 -ISPattern "Greater than"

                                If($null -eq $UninstallResult)
                                    {
                                        Write-Verbose "$($Software.NameParameter) is uninstalled successfully" -Verbose

                                        $UninstallData = [PSCustomObject]@{
                                                                                Software = $($Software.NameParameter)
                                                                                Version = $($SoftwareDetails.DisplayVersion)
                                                                                Uninstall = $true
                                                                        } | ConvertTo-Json

                                        Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                                    }
                                else
                                    {
                                        Write-Warning "$($Software.NameParameter) uninstall failed" -Verbose

                                        $UninstallData = [PSCustomObject]@{
                                                                                Software = $($Software.NameParameter)
                                                                                Version = $($SoftwareDetails.DisplayVersion)
                                                                                Uninstall = $false
                                                                            } | ConvertTo-Json

                                        Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData

                                    }
                            }
                        else
                            {
                                        Write-Verbose "$($Software.NameParameter) is not installed" -Verbose

                                        $UninstallData = [PSCustomObject]@{
                                                                            Software = $($Software.NameParameter)
                                                                            Version = "not installed"
                                                                            Uninstall = $true
                                                                        } | ConvertTo-Json

                                        Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Information -EventId 10 -Message $UninstallData
                            }
                    }
                Exit 0
            }
    }
Catch
    {
        Write-Output "Script failed: $($_.Exception.Message)"
        $UninstallData = [PSCustomObject]@{
                                                Software = $($SoftwareInst.DisplayName)
                                                Version = $($SoftwareInst.DisplayVersion)
                                                Uninstall = "Script failed: $($_.Exception.Message)"
                                            } | ConvertTo-Json

        Write-EventLog -LogName Dell -Source "Dell Software Uninstall" -EntryType Error -EventId 12 -Message $UninstallData
        Exit 1
    }