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
        throw "Unable to resolve IPv4 address for $Name: $($_.Exception.Message)"
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
        [string]$IpAddress
    )

    $rules = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue

    if (-not $rules) {
        Write-Host "Creating inbound and outbound firewall rules named '$DisplayName'" -ForegroundColor Green
        $rules = @()
        $rules += New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Profile Any -RemoteAddress $IpAddress -Enabled True
        $rules += New-NetFirewallRule -DisplayName $DisplayName -Direction Outbound -Action Allow -Profile Any -RemoteAddress $IpAddress -Enabled True
    } else {
        Write-Host "Updating remote address on existing '$DisplayName' rules" -ForegroundColor Cyan
        foreach ($rule in $rules) {
            Set-NetFirewallRule -Name $rule.Name -RemoteAddress $IpAddress -Action Allow -Enabled True | Out-Null
        }
    }
}

$resolvedIp = Resolve-IPv4Address -Name $DomainName
Write-Host "Resolved $DomainName to $resolvedIp" -ForegroundColor Green

Update-ConfigFile -Path $ConfigPath -Name $DomainName -IpAddress $resolvedIp
Ensure-FirewallRules -DisplayName $RuleDisplayName -IpAddress $resolvedIp
