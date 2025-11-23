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

$taskAction = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File `"$ScriptPath`" -DomainName `"$DomainName`" -ConfigPath `"$ConfigPath`" -RuleDisplayName `"$RuleDisplayName`""
$startTime = (Get-Date).Date.AddMinutes(1)
$taskTrigger = New-ScheduledTaskTrigger -Once -At $startTime -RepetitionInterval $Interval -RepetitionDuration ([TimeSpan]::MaxValue)
$principal = New-ScheduledTaskPrincipal -UserId $Credential.UserName -LogonType Password -RunLevel Highest

$taskSettings = New-ScheduledTaskSettingsSet -Compatibility Win8 -AllowStartIfOnBatteries -DisallowStartIfOnBatteries:$false -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $taskTrigger -Principal $principal -Settings $taskSettings -Force -Password ($Credential.GetNetworkCredential().Password)

Write-Host "Task '$TaskName' created to run whether or not the user is logged on." -ForegroundColor Green
