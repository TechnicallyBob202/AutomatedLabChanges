<#
.SYNOPSIS
    Creates AD foundation objects (OUs, Accounts, Groups) from CSV files
.DESCRIPTION
    Creates OUs, accounts, and groups needed before running the population script
    Includes existence checks and error handling for all object types
    Domain-agnostic - strips DC components from CSV and uses current domain
#>

param(
    [string]$OUsCSV = "C:\ProgramData\Semperis_Community\AutomatedLabChanges\Lists\AD_OU_Structure.csv",
    [string]$AccountsCSV = "C:\ProgramData\Semperis_Community\AutomatedLabChanges\Lists\AD_Accounts.csv",
    [string]$GroupsCSV = "C:\ProgramData\Semperis_Community\AutomatedLabChanges\Lists\AD_Groups.csv",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================================="  -ForegroundColor Green
Write-Host "        AD Foundation Object Creation Script" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "OUs CSV: $OUsCSV"
Write-Host "Accounts CSV: $AccountsCSV"
Write-Host "Groups CSV: $GroupsCSV"
if ($WhatIf) { Write-Host "MODE: WHATIF (no changes will be made)" -ForegroundColor Yellow }
Write-Host "==============================================================`n" -ForegroundColor Green

# ============================================================
# CONNECT TO DOMAIN
# ============================================================
try {
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $domainSuffix = $domain.DNSRoot
    Write-Host "Connected to domain: $domainSuffix" -ForegroundColor Green
    Write-Host "Domain DN: $domainDN" -ForegroundColor Green
}
catch {
    Write-Host "Could not connect to domain" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================
# VERIFY CSV FILES
# ============================================================
Write-Host "`nVerifying CSV files..." -ForegroundColor Cyan

$csvFiles = @(
    @{Path = $OUsCSV; Name = "OUs CSV"}
    @{Path = $AccountsCSV; Name = "Accounts CSV"}
    @{Path = $GroupsCSV; Name = "Groups CSV"}
)

foreach ($csv in $csvFiles) {
    if (-not (Test-Path $csv.Path)) {
        Write-Host "$($csv.Name) not found: $($csv.Path)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Found $($csv.Name)" -ForegroundColor Green
}

# ============================================================
# IMPORT CSV FILES
# ============================================================
Write-Host "`nImporting CSV files..." -ForegroundColor Cyan

try {
    $ous = Import-Csv -Path $OUsCSV
    $accounts = Import-Csv -Path $AccountsCSV
    $groups = Import-Csv -Path $GroupsCSV
    
    Write-Host "  OUs: $($ous.Count)" -ForegroundColor Green
    Write-Host "  Accounts: $($accounts.Count)" -ForegroundColor Green
    Write-Host "  Groups: $($groups.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Error importing CSV files" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================
# HELPER FUNCTION - Convert DN to current domain
# ============================================================
function ConvertTo-CurrentDomainDN {
    param(
        [string]$DN,
        [string]$CurrentDomainDN
    )
    
    # Strip DC components (everything from first ,DC= to end) and append current domain DN
    if ($DN -match '^(.+?),DC=') {
        # Has DC components - strip them and use the OU part
        $relativeDN = $matches[1]
        return "$relativeDN,$CurrentDomainDN"
    }
    elseif ($DN -match '^DC=') {
        # DN is just the domain root
        return $CurrentDomainDN
    }
    else {
        # No DC components, append domain DN
        return "$DN,$CurrentDomainDN"
    }
}

# ============================================================
# STATISTICS
# ============================================================
$stats = @{
    OUsCreated = 0
    OUsSkipped = 0
    OUsFailed = 0
    AccountsCreated = 0
    AccountsSkipped = 0
    AccountsFailed = 0
    GroupsCreated = 0
    GroupsSkipped = 0
    GroupsFailed = 0
}

# ============================================================
# CREATE OUs
# ============================================================
Write-Host "`n=============================================================="  -ForegroundColor Cyan
$ouCount = $ous.Count
Write-Host "Creating OUs ($ouCount total)" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

foreach ($ou in $ous) {
    
    # Convert DNs to current domain
    $ouDN = ConvertTo-CurrentDomainDN -DN $ou.DistinguishedName -CurrentDomainDN $domainDN
    $parentDN = ConvertTo-CurrentDomainDN -DN $ou.ParentPath -CurrentDomainDN $domainDN
    
    Write-Host "Processing: $($ou.Name)" -ForegroundColor White
    Write-Host "  Path: $ouDN" -ForegroundColor Gray
    
    # Check if OU already exists
    try {
        Get-ADOrganizationalUnit -Identity $ouDN -ErrorAction Stop | Out-Null
        Write-Host "  OU already exists, skipping" -ForegroundColor Yellow
        $stats.OUsSkipped++
        continue
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # OU doesn't exist, continue with creation
    }
    catch {
        Write-Host "  Error checking for existing OU" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.OUsFailed++
        continue
    }
    
    # Verify parent path exists
    try {
        Get-ADObject -Identity $parentDN -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  Parent path does not exist: $parentDN" -ForegroundColor Red
        Write-Host "    This OU will be created once its parent exists" -ForegroundColor Yellow
        $stats.OUsFailed++
        continue
    }
    
    # Create OU
    if (-not $WhatIf) {
        try {
            $ouParams = @{
                Name = $ou.Name
                Path = $parentDN
                ProtectedFromAccidentalDeletion = $false
            }
            
            if ($ou.Description) {
                $ouParams['Description'] = $ou.Description
            }
            
            New-ADOrganizationalUnit @ouParams
            
            Write-Host "  Created OU: $($ou.Name)" -ForegroundColor Green
            $stats.OUsCreated++
        }
        catch {
            Write-Host "  Failed to create OU" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            $stats.OUsFailed++
        }
    }
    else {
        Write-Host "  [WHATIF] Would create OU: $($ou.Name)" -ForegroundColor Cyan
        $stats.OUsCreated++
    }
}

Write-Host "`n==============================================================`n" -ForegroundColor Cyan

# If OUs failed, suggest re-running
if ($stats.OUsFailed -gt 0 -and -not $WhatIf) {
    Write-Host "Some OUs failed to create (possibly due to missing parents)" -ForegroundColor Yellow
    Write-Host "Re-run the script to create remaining OUs`n" -ForegroundColor Yellow
}

# ============================================================
# CREATE ACCOUNTS
# ============================================================
Write-Host "=============================================================="  -ForegroundColor Cyan
$accountCount = $accounts.Count
Write-Host "Creating Accounts ($accountCount total)" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

foreach ($account in $accounts) {
    
    # Convert OU path to current domain
    $accountOU = ConvertTo-CurrentDomainDN -DN $account.OU -CurrentDomainDN $domainDN
    
    # Update UPN to current domain
    $accountUPN = "$($account.SamAccountName)@$domainSuffix"
    
    Write-Host "Processing: $($account.Name) [$($account.SamAccountName)]" -ForegroundColor White
    
    # Check if account already exists
    try {
        Get-ADUser -Identity $account.SamAccountName -ErrorAction Stop | Out-Null
        Write-Host "  Account already exists, skipping" -ForegroundColor Yellow
        $stats.AccountsSkipped++
        continue
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # Account doesn't exist, continue with creation
    }
    catch {
        Write-Host "  Error checking for existing account" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.AccountsFailed++
        continue
    }
    
    # Verify OU exists
    try {
        Get-ADOrganizationalUnit -Identity $accountOU -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  Target OU does not exist: $accountOU" -ForegroundColor Red
        Write-Host "    Create OUs first or fix the OU path" -ForegroundColor Yellow
        $stats.AccountsFailed++
        continue
    }
    
    # Create account
    if (-not $WhatIf) {
        try {
            $passwordSecure = ConvertTo-SecureString -String $account.Password -AsPlainText -Force
            
            $userParams = @{
                Name = $account.Name
                SamAccountName = $account.SamAccountName
                UserPrincipalName = $accountUPN
                Description = $account.Description
                Path = $accountOU
                AccountPassword = $passwordSecure
                Enabled = $true
                ChangePasswordAtLogon = $false
                PasswordNeverExpires = $true
            }
            
            New-ADUser @userParams
            
            Write-Host "  Created account: $($account.SamAccountName)" -ForegroundColor Green
            $stats.AccountsCreated++
        }
        catch {
            Write-Host "  Failed to create account" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            $stats.AccountsFailed++
        }
    }
    else {
        Write-Host "  [WHATIF] Would create account: $($account.SamAccountName)" -ForegroundColor Cyan
        $stats.AccountsCreated++
    }
}

Write-Host "`n==============================================================`n" -ForegroundColor Cyan

# ============================================================
# CREATE GROUPS
# ============================================================
Write-Host "=============================================================="  -ForegroundColor Cyan
$groupCount = $groups.Count
Write-Host "Creating Groups ($groupCount total)" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

foreach ($group in $groups) {
    
    # Convert OU path to current domain
    $groupOU = ConvertTo-CurrentDomainDN -DN $group.OU -CurrentDomainDN $domainDN
    
    Write-Host "Processing: $($group.Name)" -ForegroundColor White
    
    # Check if group already exists
    try {
        Get-ADGroup -Identity $group.SamAccountName -ErrorAction Stop | Out-Null
        Write-Host "  Group already exists, skipping" -ForegroundColor Yellow
        $stats.GroupsSkipped++
        continue
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # Group doesn't exist, continue with creation
    }
    catch {
        Write-Host "  Error checking for existing group" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.GroupsFailed++
        continue
    }
    
    # Verify OU exists
    try {
        Get-ADOrganizationalUnit -Identity $groupOU -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  Target OU does not exist: $groupOU" -ForegroundColor Red
        Write-Host "    Create OUs first or fix the OU path" -ForegroundColor Yellow
        $stats.GroupsFailed++
        continue
    }
    
    # Create group
    if (-not $WhatIf) {
        try {
            $groupParams = @{
                Name = $group.Name
                SamAccountName = $group.SamAccountName
                Description = $group.Description
                GroupScope = $group.Scope
                GroupCategory = $group.Category
                Path = $groupOU
            }
            
            New-ADGroup @groupParams
            
            Write-Host "  Created group: $($group.Name)" -ForegroundColor Green
            $stats.GroupsCreated++
        }
        catch {
            Write-Host "  Failed to create group" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            $stats.GroupsFailed++
        }
    }
    else {
        Write-Host "  [WHATIF] Would create group: $($group.Name)" -ForegroundColor Cyan
        $stats.GroupsCreated++
    }
}

Write-Host "`n==============================================================`n" -ForegroundColor Cyan

# ============================================================
# SUMMARY
# ============================================================
Write-Host "=============================================================="  -ForegroundColor Green
Write-Host "                    SUMMARY STATISTICS" -ForegroundColor Green
Write-Host "==============================================================`n" -ForegroundColor Green

Write-Host "OUs:" -ForegroundColor Cyan
Write-Host "  Created: $($stats.OUsCreated)" -ForegroundColor $(if ($stats.OUsCreated -gt 0) { "Green" } else { "White" })
Write-Host "  Skipped: $($stats.OUsSkipped)" -ForegroundColor $(if ($stats.OUsSkipped -gt 0) { "Yellow" } else { "White" })
Write-Host "  Failed:  $($stats.OUsFailed)" -ForegroundColor $(if ($stats.OUsFailed -gt 0) { "Red" } else { "White" })

Write-Host "`nACCOUNTS:" -ForegroundColor Cyan
Write-Host "  Created: $($stats.AccountsCreated)" -ForegroundColor $(if ($stats.AccountsCreated -gt 0) { "Green" } else { "White" })
Write-Host "  Skipped: $($stats.AccountsSkipped)" -ForegroundColor $(if ($stats.AccountsSkipped -gt 0) { "Yellow" } else { "White" })
Write-Host "  Failed:  $($stats.AccountsFailed)" -ForegroundColor $(if ($stats.AccountsFailed -gt 0) { "Red" } else { "White" })

Write-Host "`nGROUPS:" -ForegroundColor Cyan
Write-Host "  Created: $($stats.GroupsCreated)" -ForegroundColor $(if ($stats.GroupsCreated -gt 0) { "Green" } else { "White" })
Write-Host "  Skipped: $($stats.GroupsSkipped)" -ForegroundColor $(if ($stats.GroupsSkipped -gt 0) { "Yellow" } else { "White" })
Write-Host "  Failed:  $($stats.GroupsFailed)" -ForegroundColor $(if ($stats.GroupsFailed -gt 0) { "Red" } else { "White" })

$totalCreated = $stats.OUsCreated + $stats.AccountsCreated + $stats.GroupsCreated
$totalSkipped = $stats.OUsSkipped + $stats.AccountsSkipped + $stats.GroupsSkipped
$totalFailed = $stats.OUsFailed + $stats.AccountsFailed + $stats.GroupsFailed

Write-Host "`nTOTAL:" -ForegroundColor Cyan
Write-Host "  Objects Created: $totalCreated" -ForegroundColor $(if ($totalCreated -gt 0) { "Green" } else { "White" })
Write-Host "  Objects Skipped: $totalSkipped" -ForegroundColor $(if ($totalSkipped -gt 0) { "Yellow" } else { "White" })
Write-Host "  Objects Failed:  $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })

Write-Host "`n==============================================================`n" -ForegroundColor Green

# ============================================================
# FINAL STATUS & RECOMMENDATIONS
# ============================================================
if ($WhatIf) {
    Write-Host "NOTE: This was a WHATIF run - no changes were made" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf to create objects`n" -ForegroundColor Yellow
}
elseif ($totalFailed -eq 0) {
    Write-Host "All objects created successfully!" -ForegroundColor Green
    Write-Host "You can now run the Automated-Lab-Changes.ps1 script`n" -ForegroundColor Green
}
elseif ($stats.OUsFailed -gt 0) {
    Write-Host "Some OUs failed to create" -ForegroundColor Yellow
    Write-Host "This is normal if parent OUs didn't exist yet" -ForegroundColor Yellow
    Write-Host "Re-run this script to create remaining OUs" -ForegroundColor Yellow
    Write-Host "Then accounts and groups will be created`n" -ForegroundColor Yellow
}
else {
    Write-Host "Some objects failed to create" -ForegroundColor Yellow
    Write-Host "Review errors above and re-run script`n" -ForegroundColor Yellow
}