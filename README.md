# AutomatedLabChanges

Generates realistic Active Directory activity for lab and demo environments. Simulates multiple role types performing normal AD operations on a randomized schedule, plus a separate attack simulation role for security tooling demos.

---

## Requirements

- Windows Server with AD DS role
- PowerShell 5.1+
- RSAT: Active Directory module
- RSAT: Group Policy Management (`GPMC`)
- RSAT: DNS Server tools
- WinRM enabled (script uses `Invoke-Command` to run actions on the DC)
- Script must run as a user with rights to perform AD operations, or the action accounts must have sufficient delegation

---

## Initial Setup

Run these scripts **once** before starting the main script. They create the OU structure, action accounts, groups, and initial user population the script depends on.

```
InitialSetup\Initiate_Semperis_Demo_AD.ps1   # creates OUs, accounts, groups
InitialSetup\New-ADInitialPopulation.ps1      # populates Employees OU with users
```

Both scripts read from CSV files in:
```
C:\ProgramData\Semperis_Community\AutomatedLabChanges\Lists\
```

---

## Configuration

All tunable settings are at the top of `Invoke-AutomatedLabChanges.ps1`:

| Variable | Default | Description |
|---|---|---|
| `$domainBase` | `_SemperisDSP` | Name of the root OU the script operates under |
| `$passwordDefault` | `superSECURE!` | Password used for all action accounts |
| `$actionsWait` | `150` | Seconds to wait between actions |
| `$actionsMax` | `240` | Total number of actions before the script exits |
| `$offlineUserData` | *(path)* | Path to JSON file for offline user generation |
| `$showAllActions` | `$true` | Whether to print every action to the console |

### Role Weights

Role frequency is controlled by the `$rolesList` hash table. Higher number = more frequent. Set to `0` to disable a role entirely.

```powershell
$rolesList.Add('helpdesk',    5)
$rolesList.Add('service',     4)
$rolesList.Add('desktop',     3)
$rolesList.Add('server',      2)
$rolesList.Add('domainadmin', 1)
$rolesList.Add('attack',      1)   # set to 0 to disable attack simulations
```

Action frequency within each role is controlled by the corresponding `$<role>Actions` hash table using the same weighting approach.

---

## Running the Script

```powershell
# normal run
.\Invoke-AutomatedLabChanges.ps1

# load functions and variables without executing the main loop (for testing)
.\Invoke-AutomatedLabChanges.ps1 -TestOnly
```

Logs are written to `.\Logs\AutomatedLab-Changes-<date>.log`.

---

## Testing Individual Actions

Use `Test-Actions.ps1` to run individual actions without starting the full loop. Uncomment the action(s) you want to test and run the script.

```powershell
.\Test-Actions.ps1
```

---

## Attack Simulations

The `attack` role simulates three attack patterns. Set `$rolesList['attack'] = 0` to disable all of them.

### bruteForce
Picks one random enabled user from `OU=Employees` and performs 50 repeated bad-password authentication attempts via LDAP `ValidateCredentials`. Intended to trigger account lockout and brute force IRP indicators in security tooling.

### passwordSpray
Picks 5 random enabled users from `OU=Employees` and attempts 4 common bad passwords against each. Intended to trigger password spray IRP indicators.

### lmCompatLevel
Toggles `LmCompatibilityLevel` between `1` (insecure, LM+NTLM) and `3` (NTLMv2 only) in a lab GPO on each run. Intended to generate a visible security-relevant GPO change.

---

## ⚠️ Prerequisites for Attack Simulations

### Lockout Policy
The `bruteForce` action requires a domain lockout policy to be set in order for accounts to actually lock out. By default, this lab domain has lockout disabled (`LockoutThreshold = 0`).

Set the lockout policy manually before running attack simulations:

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity <domain> `
    -LockoutThreshold 10 `
    -LockoutDuration "0.00:05:00" `
    -LockoutObservationWindow "0.00:05:00"
```

Verify with:
```powershell
Get-ADDefaultDomainPasswordPolicy | Select LockoutThreshold, LockoutDuration, LockoutObservationWindow
```

Without this, `bruteForce` will still generate Security event 4625s (bad password attempts) but accounts will not lock out, and lockout-based IRP indicators will not fire.

The script intentionally does **not** manage this policy automatically — it is a domain-wide setting that should be consciously configured for your lab.

### GPO Targets for lmCompatLevel
The `lmCompatLevel` action looks for GPOs named `Servers - ALL - Blank` or `Servers - ALL - Temporary`. These are created by the `domainadmin` role's `gpoNew` action. If neither exists, the action will skip with a warning. Run `gpoNew` at least once first, or create one of these GPOs manually.

---

## File Structure

```
AutomatedLabChanges\
├── Invoke-AutomatedLabChanges.ps1   # main script
├── Test-Actions.ps1                 # test harness
├── README.md                        # this file
├── Real-ADUser-Data-5000.json       # offline user data
├── InitialSetup\
│   ├── Initiate_Semperis_Demo_AD.ps1
│   ├── New-ADInitialPopulation.ps1
│   └── Remove-ADUsersAndGroups.ps1
├── Lists\                           # CSV files for initial setup
├── Logs\                            # script run logs (auto-created)
└── Scheduled Tasks\                 # task scheduler XML exports
```