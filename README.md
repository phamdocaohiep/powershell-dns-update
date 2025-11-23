# PowerShell DNS Update & Firewall Sync

This repository provides a PowerShell job script that resolves `phamdocaohiep.io.vn`,
updates a JSON configuration file with its current IP address, and ensures the Windows
Firewall rule **Allow API** permits inbound and outbound access to that IP.

## Files
- `Update-ApiFirewall.ps1`: Main script that resolves the domain, updates the config file, and syncs the firewall rule.
- `config.json`: Sample configuration file storing friendly names and IP addresses.

## Usage
Run the script manually to update the configuration and firewall rules:

```powershell
pwsh -File ./Update-ApiFirewall.ps1 -DomainName "phamdocaohiep.io.vn" -ConfigPath "./config.json" -RuleDisplayName "Allow API"
```

### Scheduling with Task Scheduler (Windows)
#### Automated creation (run while logged on or off)
Use the helper script to register a task that runs even when the user is not logged on:

```powershell
# Run in an elevated PowerShell session
pwsh -File ./Create-ApiFirewallTask.ps1 `
  -TaskName "Refresh-Allow-API" `
  -DomainName "phamdocaohiep.io.vn" `
  -ConfigPath "C:\Path\To\config.json" `
  -RuleDisplayName "Allow API" `
  -ScriptPath "C:\Path\To\Update-ApiFirewall.ps1" `
  -Interval (New-TimeSpan -Minutes 30) `
  -User "DOMAIN\service-account"
```

The script prompts for the password of the specified account, then registers a task that:
- Runs whether or not the user is logged on.
- Uses the highest privileges.
- Repeats at the chosen interval (default 30 minutes) indefinitely.

#### Manual creation
1. Open **Task Scheduler** → **Create Task**.
2. On **General**, select **Run whether user is logged on or not** and **Run with highest privileges**.
3. On **Triggers**, add a schedule (for example, repeat every 30 minutes).
4. On **Actions**, choose **Start a program** and set:
   - **Program/script:** `pwsh`
   - **Add arguments:** `-File "C:\Path\To\Update-ApiFirewall.ps1" -DomainName "phamdocaohiep.io.vn" -ConfigPath "C:\Path\To\config.json" -RuleDisplayName "Allow API"`
   - **Start in:** `C:\Path\To` (folder containing the script and config file)
5. Save the task. The job will periodically refresh DNS, update `config.json`, and align the **Allow API** inbound/outbound firewall rules to the latest IP.

### Notes
- The script uses `Resolve-DnsName` to fetch the latest IPv4 address. If DNS fails, the script stops with a clear error.
- Existing entries for `phamdocaohiep.io.vn` in `config.json` are updated in place; if the entry is missing, it is added automatically.
- If the firewall rule named **Allow API** does not exist, the script creates inbound and outbound rules; otherwise, it updates their `RemoteAddress` values.
