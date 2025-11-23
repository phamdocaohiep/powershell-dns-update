param(
    [string]$TaskName = "Refresh-Allow-API",
    [string]$DomainName = "phamdocaohiep.io.vn",
    [string]$ConfigPath = "D:\\Project\\dns-config\\config.json",
    [string]$RuleDisplayName = "Allow API",
    [string]$ScriptPath = "D:\\Project\\dns-config\\Update-ApiFirewall.ps1",
    [TimeSpan]$Interval = (New-TimeSpan -Minutes 30),
    [string]$User = $(whoami),
    [pscredential]$Credential
)

if ($Credential) {
    $User = $Credential.UserName
} else {
    # Prompt for credentials when running under a specific account
    $securePassword = Read-Host "Enter password for $User" -AsSecureString
    $Credential = New-Object System.Management.Automation.PSCredential($User, $securePassword)
}

if (-not (Test-Path $ScriptPath)) {
    throw "Script path not found: $ScriptPath"
}

# Check for existing task and remove it
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Found existing task '$TaskName', removing it..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Existing task removed successfully." -ForegroundColor Green
}

$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`" -DomainName `"$DomainName`" -ConfigPath `"$ConfigPath`" -RuleDisplayName `"$RuleDisplayName`""
$startTime = (Get-Date).Date.AddMinutes(1)
$taskTrigger = New-ScheduledTaskTrigger -Once -At $startTime -RepetitionInterval $Interval -RepetitionDuration ([TimeSpan]::FromDays(9999))
$principal = New-ScheduledTaskPrincipal -UserId $Credential.UserName -LogonType Password -RunLevel Highest

$taskSettings = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User $Credential.UserName -Password ($Credential.GetNetworkCredential().Password) -RunLevel Highest -Force

Write-Host "Task '$TaskName' created to run whether or not the user is logged on." -ForegroundColor Green
