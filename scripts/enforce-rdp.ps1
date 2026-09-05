$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$controlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"

# Check the MDM policy value (default to 1 / denied if the policy key isn't found)
$desiredState = 1
if (Test-Path $policyPath) {
    $val = (Get-ItemProperty -Path $policyPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
    if ($null -ne $val) {
        $desiredState = $val
    }
}

# Apply the discovered policy state to the live control register
$currentLiveState = (Get-ItemProperty -Path $controlPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections

if ($currentLiveState -ne $desiredState) {
    Set-ItemProperty -Path $controlPath -Name "fDenyTSConnections" -Value $desiredState -Force
    Restart-Service TermService -Force
}