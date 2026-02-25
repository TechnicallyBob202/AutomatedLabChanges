#!/usr/bin/env pwsh
<#
.SYNOPSIS
Automated AD Lab Activity Generator - Refactored

.DESCRIPTION
Generates realistic Active Directory activity via random or explicit test actions.
Configuration-driven via JSON files for easy customization.

.EXAMPLE
.\Invoke-AutomatedLabChanges.ps1

.NOTES
This is the refactored version. Original: ../Invoke-AutomatedLabChanges.ps1
#>

param(
    [string]$ConfigPath = './config/settings.json',
    [string]$ActionsPath = './config/actions.json'
)

# Set error handling
$ErrorActionPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

# Load library functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$libPath = Join-Path $scriptPath 'lib'

Write-Host "Loading modules..." -ForegroundColor Cyan
. (Join-Path $libPath 'Config.ps1')
. (Join-Path $libPath 'ActionRouter.ps1')
. (Join-Path $libPath 'Actions.ps1')

# Load configuration
Write-Host "Loading configuration..." -ForegroundColor Cyan
$config = Get-ScriptConfiguration -SettingsPath $ConfigPath -ActionsPath $ActionsPath

$settings = $config.settings
$actions = $config.actions

# Get current date for logging
$logDate = Get-Date -Format 'yyyy-MM-dd'
$logDir = Join-Path $scriptPath ($settings.logging.logFilePath)
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$logFile = Join-Path $logDir ("AutomatedLab-Changes-$logDate.log")

# Start transcript
Start-Transcript -Path $logFile -Append | Out-Null

Write-Host "=============================================================="
Write-Host "        Automated Lab Activity Generator (Refactored)         "
Write-Host "                        $logDate                             "
Write-Host "=============================================================="
Write-Host "Domain: $($settings.domain.baseName)"
Write-Host "Log file: $logFile"
Write-Host ""

# Import Group Policy Module
Import-Module GroupPolicy -ErrorAction SilentlyContinue

# ============================================================================
# INITIALIZE DOMAIN VARIABLES
# ============================================================================

try {
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $domainSuffix = $domain.DNSRoot
    $dcName = (Get-ADDomainController -Discover).HostName
}
catch {
    Write-Host "ERROR: Could not contact domain" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}

# Setup globals from original script (needed for actions)
$domainBase = $settings.domain.baseName
$showAllActions = $settings.logging.showAllActions
$continueOnError = -not $settings.credentials.continueOnError
$passwordDefault = $settings.credentials.passwordDefault
$passwordSecure = ConvertTo-SecureString -String "$passwordDefault" -AsPlainText -Force

# Offline user data
$offlineUserData = $settings.userData.offlineDataPath
$userCountryCodes = $settings.userData.countryCode

# OU base paths
$domainBaseLocation = "OU=$domainBase,$domainDN"

# Build OU structure (from original script)
$baseOUS = @(
    @{ID = 0; Name = "$domainBase"; Path = "$domainDN"; DN = "OU=$domainBase,$domainDN" },
    @{ID = 1; Name = "_New"; Path = "$domainBaseLocation"; DN = "OU=_New,$domainBaseLocation"; Code = "defNew" },
    @{ID = 2; Name = "Computer"; Path = "OU=_New,$domainBaseLocation"; DN = "OU=Computer,OU=_New,$domainBaseLocation"; Code = "defNewComputer" },
    @{ID = 3; Name = "User"; Path = "OU=_New,$domainBaseLocation"; DN = "OU=User,OU=_New,$domainBaseLocation"; Code = "defNewUser" },
    @{ID = 4; Name = "_Expired"; Path = "$domainBaseLocation"; DN = "OU=_Expired,$domainBaseLocation" },
    @{ID = 5; Name = "Employees"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Employees,OU=_Expired,$domainBaseLocation"; Code = "defEmployeesExpired" },
    @{ID = 6; Name = "Groups"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Groups,OU=_Expired,$domainBaseLocation"; Code = "defGroupsExpired" },
    @{ID = 7; Name = "Servers"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Servers,OU=_Expired,$domainBaseLocation"; Code = "defServersExpired" },
    @{ID = 8; Name = "Workstations"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Workstations,OU=_Expired,$domainBaseLocation"; Code = "defWorkstationsExpired" },
    @{ID = 9; Name = "Administrative"; Path = "$domainBaseLocation"; DN = "OU=Administrative,$domainBaseLocation"; Code = "defAdmin" },
    @{ID = 10; Name = "Confidential"; Path = "$domainBaseLocation"; DN = "OU=Confidential,$domainBaseLocation"; Code = "defConfidential" },
    @{ID = 11; Name = "Departments"; Path = "$domainBaseLocation"; DN = "OU=Departments,$domainBaseLocation"; Code = "defDepartments" },
    @{ID = 12; Name = "Employees"; Path = "$domainBaseLocation"; DN = "OU=Employees,$domainBaseLocation"; Code = "defEmployees" },
    @{ID = 13; Name = "VIPs"; Path = "OU=Employees,$domainBaseLocation"; DN = "OU=VIPs,OU=Employees,$domainBaseLocation"; Code = "defEmployeesVips" },
    @{ID = 14; Name = "Groups"; Path = "$domainBaseLocation"; DN = "OU=Groups,$domainBaseLocation"; Code = "defGroups" },
    @{ID = 15; Name = "Quarantined"; Path = "$domainBaseLocation"; DN = "OU=Quarantined,$domainBaseLocation" },
    @{ID = 16; Name = "Employees"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Employees,OU=Quarantined,$domainBaseLocation"; Code = "defEmployeesQuarantined" },
    @{ID = 17; Name = "Groups"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Groups,OU=Quarantined,$domainBaseLocation"; Code = "defGroupsQuarantined" },
    @{ID = 18; Name = "Servers"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Servers,OU=Quarantined,$domainBaseLocation"; Code = "defServersQuarantined" },
    @{ID = 19; Name = "Workstations"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Workstations,OU=Quarantined,$domainBaseLocation"; Code = "defWorkstationsQuarantined" },
    @{ID = 20; Name = "Servers"; Path = "$domainBaseLocation"; DN = "OU=Servers,$domainBaseLocation"; Code = "defServers" },
    @{ID = 21; Name = "Workstations"; Path = "$domainBaseLocation"; DN = "OU=Workstations,$domainBaseLocation"; Code = "defWorkstations" },
    @{ID = 22; Name = "Engineering"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=Engineering,OU=Workstations,$domainBaseLocation"; Code = "defEngineeringWorkstations" },
    @{ID = 23; Name = "Field"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=Field,OU=Workstations,$domainBaseLocation"; Code = "defFieldWorkstations" }, 
    @{ID = 24; Name = "Kiosks"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=Kiosks,OU=Workstations,$domainBaseLocation"; Code = "defKiosksWorkstations" },
    @{ID = 25; Name = "VDI"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=VDI,OU=Workstations,$domainBaseLocation"; Code = "defVDIWorkstations" }
)

# Set OU variables for action functions
$ouConfidential = ($baseOUS | Where-Object { $_.Code -eq 'defConfidential' }).DN
$ouDepartments = ($baseOUS | Where-Object { $_.Code -eq 'defDepartments' }).DN
$ouEmployees = ($baseOUS | Where-Object { ($_.Code -eq 'defEmployees') }).DN
$ouEmployeesExpired = ($baseOUS | Where-Object { ($_.Code -eq 'defEmployeesExpired') }).DN
$ouEmployeesQuarantined = ($baseOUS | Where-Object { ($_.Code -eq 'defEmployeesQuarantined') }).DN
$ouEmployeesVIP = ($baseOUS | Where-Object { $_.Code -eq 'defEmployeesVips' }).DN
$ouGroups = ($baseOUS | Where-Object { $_.Code -eq 'defGroups' }).DN
$ouGroupsExpired = ($baseOUS | Where-Object { ($_.Code -eq 'defGroupsExpired') }).DN
$ouGroupsQuarantined = ($baseOUS | Where-Object { ($_.Code -eq 'defGroupsQuarantined') }).DN
$ouServers = ($baseOUS | Where-Object { ($_.Code -eq 'defServers') }).DN
$ouServersExpired = ($baseOUS | Where-Object { ($_.Code -eq 'defServersExpired') }).DN
$ouServersQuarantined = ($baseOUS | Where-Object { ($_.Code -eq 'defServersQuarantined') }).DN
$ouWorkstations = ($baseOUS | Where-Object { ($_.Code -eq 'defWorkstations') }).DN
$ouWorkstationsExpired = ($baseOUS | Where-Object { ($_.Code -eq 'defWorkstationsExpired') }).DN
$ouWorkstationsQuarantined = ($baseOUS | Where-Object { ($_.Code -eq 'defWorkstationsQuarantined') }).DN
$ouNewComputers = ($baseOUS | Where-Object { ($_.Code -eq 'defNewComputer') }).DN
$ouNewUsers = ($baseOUS | Where-Object { ($_.Code -eq 'defNewUser') }).DN

# Action accounts
$actionAccounts = @(
    @{ID = "domainadmin"; Tier = "Tier0"; TierGroup = "T0_Admins_Global_RG"; AccountName = "domain-admin" }
    @{ID = "rogue"; Tier = "Tier0"; TierGroup = "T0_Admins_Global_RG"; AccountName = "rogue-admin" }
    @{ID = "network"; Tier = "Tier1"; TierGroup = "T1_NetworkAdmin_Global_RG"; AccountName = "network-admin" }
    @{ID = "server"; Tier = "Tier1"; TierGroup = "T1_ServerAdmin_Global_RG"; AccountName = "server-admin" }
    @{ID = "desktop"; Tier = "Tier2"; TierGroup = "T2_DesktopSupport_Global_RG"; AccountName = "desktop-admin" }
    @{ID = "helpdesk"; Tier = "Tier2"; TierGroup = "T2_HelpDesk_RG"; AccountName = "helpdesk-admin" }
    @{ID = "cloud"; Tier = "TierCloud"; TierGroup = "TC_CloudAdmins_RG"; AccountName = "cloud-admin" }    
    @{ID = "vipadmin"; Tier = "Tier2"; TierGroup = "T2_VIP_Support_RG"; AccountName = "vip-admin" }        
)

# Departments and roles
$departments = @(
    @{"Name" = "Accounting"; Positions = @("Accounting Manager", "Accounts Clerk", "Data Entry", "Cost Accountant") },
    @{"Name" = "Administration"; Positions = @("Administration Manager", "Administrator", "Administration Assistant") },
    @{"Name" = "IT"; Positions = @("Manager", "Support Tech", "Technician", "Architect", "HelpDesk", "Systems Admin") },
    @{"Name" = "Engineering"; Positions = @("Engineering Manager", "Engineer", "Data Scientist", "Design Engineer") },
    @{"Name" = "Operations"; Positions = @("Operations Manager", "Operations Analyst") },
    @{"Name" = "Sales"; Positions = @("Sales Manager", "Sales Representative", "Sales Consultant") },
    @{"Name" = "Marketing"; Positions = @("Marketing Manager", "Marketing Coordinator", "Marketing Specialist") },
    @{"Name" = "Human Resources"; Positions = @("Human Resources Manager", "Payroll", "HR Coordinator") },
    @{"Name" = "C-Suite"; Positions = @("CIO", "CEO", "CFO", "COO", "CISO") }
)

$departmentsJobLevels = @("I", "II", "III", "IV", "V")

# Enterprise apps
$enterpriseApps = @(
    @{ID = "APP"; Name = "Application Server"; Description = "Application Server" }    
    @{ID = "BCKP"; Name = "Backup"; Description = "Backup Solutions" }
    @{ID = "DBMS"; Name = "Database"; Description = "Database" }
    @{ID = "ERP"; Name = "Enterprise Resource Planning"; Description = "Enterprise Resource Planning" }
    @{ID = "MAIL"; Name = "Email"; Description = "Email" }
    @{ID = "FSRV"; Name = "File Server"; Description = "File Server" }
    @{ID = "WEB"; Name = "Webserver"; Description = "Webserver" }
    @{ID = "LNX"; Name = "Linux"; Description = "Linux" }
)

$enterpriseAppsEnvironments = @("DEV", "QA", "PRD")
$osVersionsWindows = @("Windows Server 2016", "Windows Server 2019", "Windows Server 2022")
$osVersionsLinux = @("Ubuntu 22.04", "RHEL 9")
$servicePrincipalNames = @('CIFS', 'HOST', 'HTTP', 'MSSQlSvc', 'TERMSRV', 'W3SVC', 'WSMAN')

$confidentialGroups = @(
    @{ID = "1"; Name = "TLP - Red"; Description = "Restricted sharing - highly sensitive data" },
    @{ID = "2"; Name = "TLP - Amber"; Description = "Limited sharing - need-to-know basis" },
    @{ID = "3"; Name = "TLP - Green"; Description = "Community sharing - trusted group only" },
    @{ID = "4"; Name = "TLP - Clear"; Description = "Unrestricted sharing - public" }
)

$selectedDepartments = $departments
$selectedEnterpriseApps = $enterpriseApps

# ============================================================================
# LOAD USER DATA
# ============================================================================

Write-Host "Loading user data..." -ForegroundColor Cyan

if ($offlineUserData -ne "") {
    try {
        if (Test-Path -Path $offlineUserData) {
            try {
                $usersToCreate = Get-Content -Path $offlineUserData -Raw | ConvertFrom-Json                
            } 
            catch {
                Write-Host "WARNING: Failed to import offline data file" -ForegroundColor Yellow
                $usersToCreate = $null
            }
        }
        else {
            Write-Host "WARNING: Could not find offline data file at $offlineUserData" -ForegroundColor Yellow
            $usersToCreate = $null
        }
    }
    catch {
        Write-Host "WARNING: Offline data file not valid" -ForegroundColor Yellow
        $usersToCreate = $null
    }
}

if ($null -eq $usersToCreate) {
    try {
        Write-Host "Attempting to download user data from randomuser.me API..." -ForegroundColor Cyan
        $usersToCreate = Invoke-RestMethod -Uri "https://randomuser.me/api/?results=5000&inc=name,location,nat&nat=$userCountryCodes&dl" | Select-Object -ExpandProperty Results
        Write-Host "User data downloaded successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: Could not download user data from API" -ForegroundColor Yellow
        Write-Host "Some user creation actions may fail" -ForegroundColor Yellow
        $usersToCreate = @()
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "=============================================================="
Write-Host "        Automated Lab Activity Generator (Refactored)         "
Write-Host "                        $logDate                             "
Write-Host "=============================================================="
Write-Host "Domain: $domainSuffix"
Write-Host "Log file: $logFile"
Write-Host ""

# Determine mode
$testModeEnabled = $settings.testMode.enabled
$normalModeEnabled = $settings.normalMode.enabled

if ($testModeEnabled) {
    Write-Host "MODE: TEST" -ForegroundColor Yellow
    Write-Host "Running enabled actions from config/actions.json" -ForegroundColor Yellow
    Write-Host ""
    
    # Filter to enabled actions only
    $enabledActions = $actions | Where-Object { $_.enabled -eq $true }
    
    if ($enabledActions.Count -eq 0) {
        Write-Host "No actions enabled for testing. Edit config/actions.json and set enabled=true" -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
    
    Write-Host "Test Actions Enabled: $($enabledActions.Count)" -ForegroundColor Green
    $enabledActions | ForEach-Object {
        Write-Host "  [$($_.role)] $($_.name) - $($_.description)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    $actionCount = $settings.testMode.actionCount
    $delaySeconds = $settings.testMode.delayBetweenActions
    
    # Execute each enabled action
    $actionIndex = 0
    foreach ($testAction in $enabledActions) {
        $actionIndex++
        $role = $testAction.role
        $actionName = $testAction.name
        
        Write-Host "[$actionIndex/$($enabledActions.Count)] Testing $role :: $actionName" -ForegroundColor Green
        Write-Host "  Description: $($testAction.description)"
        Write-Host "  Running $actionCount time(s)..."
        
        for ($i = 1; $i -le $actionCount; $i++) {
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HH:mm:ss'
            Write-Host "    [$i/$actionCount] $timestamp" -ForegroundColor Cyan
            
            # Execute the action
            switch ($role) {
                desktop { Invoke-DesktopAction -desktopAction $actionName }
                domainadmin { Invoke-DomainAdminAction -domainAdminAction $actionName }
                helpdesk { Invoke-HelpdeskAction -helpdeskAction $actionName }
                server { Invoke-ServerAction -serverAction $actionName }
                service { Invoke-ServiceAccountAction -serviceAccount $actionName }
            }
            
            if ($i -lt $actionCount) {
                Start-Sleep -Seconds $delaySeconds
            }
        }
        
        Write-Host ""
    }
    
    Write-Host "TEST MODE COMPLETE - $($enabledActions.Count) action(s) tested" -ForegroundColor Green

} elseif ($normalModeEnabled) {
    Write-Host "MODE: NORMAL (Random Activity)" -ForegroundColor Yellow
    Write-Host "Max actions: $($settings.normalMode.maxActions)" -ForegroundColor Cyan
    Write-Host "Delay between actions: $($settings.normalMode.delayBetweenActions)s" -ForegroundColor Cyan
    Write-Host ""
    
    # Filter to enabled actions
    $enabledActions = $actions | Where-Object { $_.enabled -eq $true }
    
    if ($enabledActions.Count -eq 0) {
        Write-Host "No actions enabled. Edit config/actions.json" -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
    
    $maxActions = $settings.normalMode.maxActions
    $delaySeconds = $settings.normalMode.delayBetweenActions
    
    # Build weighted role list
    $roleWeights = @{
        'helpdesk' = 5
        'service' = 4
        'desktop' = 3
        'server' = 2
        'domainadmin' = 1
    }
    
    $rolesWeighted = @()
    foreach ($r in $roleWeights.Keys) {
        for ($w = 1; $w -le $roleWeights[$r]; $w++) {
            $rolesWeighted += $r
        }
    }
    
    Write-Host "Enabled actions for random selection: $($enabledActions.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 1; $i -le $maxActions; $i++) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd_HH:mm:ss'
        Write-Host "[$i/$maxActions] $timestamp" -ForegroundColor Cyan
        
        # Select random role
        $selectedRole = $rolesWeighted | Get-Random
        
        # Get actions for this role
        $roleActions = $enabledActions | Where-Object { $_.role -eq $selectedRole }
        
        if ($roleActions.Count -gt 0) {
            # Select random action based on weight
            $selectedAction = $roleActions | Get-Random
            
            Write-Host "  Executing: $selectedRole :: $($selectedAction.name)" -ForegroundColor Cyan
            
            # Execute
            switch ($selectedRole) {
                desktop { Invoke-DesktopAction -desktopAction $selectedAction.name }
                domainadmin { Invoke-DomainAdminAction -domainAdminAction $selectedAction.name }
                helpdesk { Invoke-HelpdeskAction -helpdeskAction $selectedAction.name }
                server { Invoke-ServerAction -serverAction $selectedAction.name }
                service { Invoke-ServiceAccountAction -serviceAccount $selectedAction.name }
            }
        }
        
        Write-Host ""
        
        Start-Sleep -Seconds $delaySeconds
    }
    
    Write-Host "NORMAL MODE COMPLETE" -ForegroundColor Green

} else {
    Write-Host "ERROR: Neither test mode nor normal mode is enabled" -ForegroundColor Red
    Write-Host "Edit config/settings.json to enable testMode or normalMode" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host "=============================================================="
Write-Host "Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=============================================================="

Stop-Transcript
