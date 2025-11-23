param(
    [string]$DomainName = "phamdocaohiep.io.vn",
    [string]$ConfigPath = "./config.json",
    [string]$RuleDisplayName = "Allow API"
)

function Resolve-IPv4Address {
    param([string]$Name)
    try {
        $dnsResult = Resolve-DnsName -Name $Name -Type A -ErrorAction Stop | Where-Object { $_.IPAddress }
        $dnsResult[0].IPAddress
    } catch {
        throw "Unable to resolve IPv4 address for ${Name}: $($_.Exception.Message)"
    }
}

function Update-ConfigFile {
    param(
        [string]$Path,
        [string]$Name,
        [string]$IpAddress
    )

    if (-not (Test-Path $Path)) {
        Write-Host "Config file not found, creating new file at $Path" -ForegroundColor Yellow
        $entries = @()
    } else {
        $content = Get-Content -Path $Path -Raw
        $entries = if ($content.Trim()) { $content | ConvertFrom-Json } else { @() }
        if (-not ($entries -is [System.Collections.IEnumerable])) { $entries = @($entries) }
    }

    $updated = $false
    $entries = $entries | ForEach-Object {
        if ($_.name -eq $Name) {
            if ($_.ip -ne $IpAddress) {
                Write-Host "Updating IP for $Name from $($_.ip) to $IpAddress" -ForegroundColor Cyan
            }
            $_.ip = $IpAddress
            $updated = $true
        }
        $_
    }

    if (-not $updated) {
        Write-Host "Adding new entry for $Name with IP $IpAddress" -ForegroundColor Green
        $entries += [pscustomobject]@{ ip = $IpAddress; name = $Name }
    }

    $entries | ConvertTo-Json -Depth 3 | Set-Content -Path $Path -Encoding UTF8
}

function Ensure-FirewallRules {
    param(
        [string]$DisplayName,
        [array]$IpAddresses
    )

    $ipList = $IpAddresses -join ', '
    $rules = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue

    if (-not $rules) {
        Write-Host "Creating inbound and outbound firewall rules named '$DisplayName'" -ForegroundColor Green
        $rules = @()
        $rules += New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Profile Any -RemoteAddress $IpAddresses -Enabled True
        $rules += New-NetFirewallRule -DisplayName $DisplayName -Direction Outbound -Action Allow -Profile Any -RemoteAddress $IpAddresses -Enabled True
    } else {
        Write-Host "Updating remote address on existing '$DisplayName' rules with: $ipList" -ForegroundColor Cyan
        foreach ($rule in $rules) {
            Set-NetFirewallRule -Name $rule.Name -RemoteAddress $IpAddresses -Action Allow -Enabled True | Out-Null
        }
    }
}

$resolvedIp = Resolve-IPv4Address -Name $DomainName
Write-Host "Resolved $DomainName to $resolvedIp" -ForegroundColor Green

# Load current config first
$content = Get-Content -Path $ConfigPath -Raw
$allEntries = if ($content.Trim()) { $content | ConvertFrom-Json } else { @() }
if (-not ($allEntries -is [System.Collections.IEnumerable])) { $allEntries = @($allEntries) }

# Update or add the resolved domain IP
Update-ConfigFile -Path $ConfigPath -Name $DomainName -IpAddress $resolvedIp

# Reload config after update to get all IPs
$content = Get-Content -Path $ConfigPath -Raw
$allEntries = $content | ConvertFrom-Json
$allIps = @($allEntries | ForEach-Object { $_.ip })

Write-Host "Complete IP list from config ($($allIps.Count) addresses): $($allIps -join ', ')" -ForegroundColor Yellow
Ensure-FirewallRules -DisplayName $RuleDisplayName -IpAddresses $allIps
