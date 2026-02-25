# Invoke-AutomatedLabChanges - Refactored

Clean, modular refactor of the 2000+ line Active Directory lab automation script.

## Structure

```
├── Invoke-AutomatedLabChanges.ps1    Main orchestrator script
├── lib/
│   ├── Config.ps1                    Configuration loader
│   ├── ActionRouter.ps1              Action execution router
│   └── Actions.ps1                   (TODO) All action implementations
├── config/
│   ├── settings.json                 Main script settings
│   └── actions.json                  Action metadata & enabled status
└── logs/
    └── *.log                         Script logs
```

## Quick Start

### Normal Mode (Random Actions)
```powershell
# Edit config/settings.json
# Set: "normalMode.enabled": true
# Set: "testMode.enabled": false

.\Invoke-AutomatedLabChanges.ps1
```

### Test Mode (Specific Actions)

Edit `config/actions.json` and set `"enabled": true` for actions you want to test:

```json
{
  "role": "desktop",
  "name": "computerNew",
  "enabled": true,     // Enable this action for testing
  "weight": 5,
  "description": "Create new workstation"
}
```

Then set test mode in `config/settings.json`:
```json
"testMode": {
  "enabled": true,
  "actionCount": 1,
  "delayBetweenActions": 2
}
```

Run:
```powershell
.\Invoke-AutomatedLabChanges.ps1
```

## Configuration

### actions.json
- **role**: desktop, helpdesk, server, service, domainadmin
- **name**: action name (matches function implementation)
- **weight**: likelihood in normal mode (1-5)
- **enabled**: true/false for test mode filtering
- **description**: what the action does

### settings.json
- **testMode.enabled**: Enable/disable test mode
- **testMode.actionCount**: How many times to run each enabled action
- **normalMode.enabled**: Enable/disable random mode
- **normalMode.maxActions**: Total actions to run
- **normalMode.delayBetweenActions**: Seconds between actions

## Benefits Over Original

| Original | Refactored |
|----------|-----------|
| 2000+ lines | 100-line main script + config |
| 37 scattered test flags | JSON configuration |
| 5 massive switch functions | Modular action implementations |
| Hard to enable/disable actions | Edit JSON, no code changes |
| Testing bolted on | Testing first-class citizen |

## Testing Actions

To test specific actions:

1. Edit `config/actions.json`
2. Find actions you want to test
3. Set `"enabled": true` for those actions
4. Set all others to `"enabled": false`
5. In `config/settings.json`, enable test mode
6. Run the script

Example: Test only `desktop::computerNew` and `helpdesk::passwordReset`

```json
// config/actions.json - set enabled for these two:
{ "role": "desktop", "name": "computerNew", "enabled": true, ... }
{ "role": "helpdesk", "name": "passwordReset", "enabled": true, ... }

// Set all others to "enabled": false

// config/settings.json
"testMode": {
  "enabled": true,
  "actionCount": 3,           // Run each action 3 times
  "delayBetweenActions": 2
}
```

Output:
```
TEST MODE ENABLED
Running enabled test actions (3 iterations each)

[1] Testing desktop :: computerNew (3 iterations)
  [1/3] 2026-02-09_14:15:23
    + created computer: ENG-XYZABC42
  [2/3] 2026-02-09_14:15:25
    + created computer: WKS-ABCDEF78
  [3/3] 2026-02-09_14:15:27
    + created computer: VDI-HIJKLM99

[2] Testing helpdesk :: passwordReset (3 iterations)
  [1/3] 2026-02-09_14:15:29
    + changed password: user.smith
  [2/3] 2026-02-09_14:15:31
    + changed password: user.jones
  [3/3] 2026-02-09_14:15:33
    + changed password: user.brown

TEST MODE COMPLETE - 2 action(s) tested
```

## TODO

- [ ] Move action implementations from 5 functions into modular lib/Actions.ps1
- [ ] Add parameter validation
- [ ] Add dry-run mode
- [ ] Add action timing/statistics
- [ ] CI/CD integration via environment variables
