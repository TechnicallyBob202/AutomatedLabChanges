<#
.SYNOPSIS
    Creates AD foundation objects (OUs, Accounts, Groups) from CSV files
.DESCRIPTION
    Creates OUs, accounts, and groups needed before running the population script
    Includes existence checks and error handling for all object types
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
    Write-Host "✓ Connected to domain: $domainSuffix" -ForegroundColor Green
}
catch {
    Write-Host "✗ Could not connect to domain" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "✗ $($csv.Name) not found: $($csv.Path)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✓ Found $($csv.Name)" -ForegroundColor Green
}

# ============================================================
# IMPORT CSV FILES
# ============================================================
Write-Host "`nImporting CSV files..." -ForegroundColor Cyan

try {
    $ous = Import-Csv -Path $OUsCSV
    $accounts = Import-Csv -Path $AccountsCSV
    $groups = Import-Csv -Path $GroupsCSV
    
    Write-Host "  ✓ OUs: $($ous.Count)" -ForegroundColor Green
    Write-Host "  ✓ Accounts: $($accounts.Count)" -ForegroundColor Green
    Write-Host "  ✓ Groups: $($groups.Count)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error importing CSV files" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
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
Write-Host "Creating OUs ($($ous.Count) total)" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

foreach ($ou in $ous) {
    
    Write-Host "Processing: $($ou.Name)" -ForegroundColor White
    Write-Host "  Path: $($ou.DistinguishedName)" -ForegroundColor Gray
    
    # Check if OU already exists
    try {
        $existingOU = Get-ADOrganizationalUnit -Identity $ou.DistinguishedName -ErrorAction Stop
        Write-Host "  ⊘ OU already exists, skipping" -ForegroundColor Yellow
        $stats.OUsSkipped++
        continue
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # OU doesn't exist, continue with creation
    }
    catch {
        Write-Host "  ✗ Error checking for existing OU" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.OUsFailed++
        continue
    }
    
    # Verify parent path exists
    try {
        Get-ADObject -Identity $ou.ParentPath -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  ✗ Parent path does not exist: $($ou.ParentPath)" -ForegroundColor Red
        Write-Host "    This OU will be created once its parent exists" -ForegroundColor Yellow
        $stats.OUsFailed++
        continue
    }
    
    # Create OU
    if (-not $WhatIf) {
        try {
            $ouParams = @{
                Name = $ou.Name
                Path = $ou.ParentPath
                ProtectedFromAccidentalDeletion = $false
            }
            
            if ($ou.Description) {
                $ouParams['Description'] = $ou.Description
            }
            
            New-ADOrganizationalUnit @ouParams
            
            Write-Host "  ✓ Created OU: $($ou.Name)" -ForegroundColor Green
            $stats.OUsCreated++
        }
        catch {
            Write-Host "  ✗ Failed to create OU" -ForegroundColor Red
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
    Write-Host "⚠ Some OUs failed to create (possibly due to missing parents)" -ForegroundColor Yellow
    Write-Host "  Re-run the script to create remaining OUs`n" -ForegroundColor Yellow
}

# ============================================================
# CREATE ACCOUNTS
# ============================================================
Write-Host "=============================================================="  -ForegroundColor Cyan
Write-Host "Creating Accounts ($($accounts.Count) total)" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

foreach ($account in $accounts) {
    
    Write-Host "Processing: $($account.Name) [$($account.SamAccountName)]" -ForegroundColor White
    
    # Check if account already exists
    try {
        $existingUser = Get-ADUser -Identity $account.SamAccountName -ErrorAction Stop
        Write-Host "  ⊘ Account already exists, skipping" -ForegroundColor Yellow
        $stats.AccountsSkipped++
        continue
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # Account doesn't exist, continue with creation
    }
    catch {
        Write-Host "  ✗ Error checking for existing account" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.AccountsFailed++
        continue
    }
    
    # Verify OU exists
    try {
        Get-ADOrganizationalUnit -Identity $account.OU -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  ✗ Target OU does not exist: $($account.OU)" -ForegroundColor Red
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
                UserPrincipalName = $account.UserPrincipalName
                Description = $account.Description
                Path = $account.OU
                AccountPassword = $passwordSecure
                Enabled = $true
                ChangePasswordAtLogon = $false
                PasswordNeverExpires = $true
            }
            
            New-ADUser @userParams
            
            Write-Host "  ✓ Created account: $($account.SamAccountName)" -ForegroundColor Green
            $stats.AccountsCreated++
        }
        catch {
            Write-Host "  ✗ Failed to create account" -ForegroundColor Red
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
Write-Host "Creating Groups ($($groups.Count) total)" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

foreach ($group in $groups) {
    
    Write-Host "Processing: $($group.Name)" -ForegroundColor White
    
    # Check if group already exists
    try {
        $existingGroup = Get-ADGroup -Identity $group.SamAccountName -ErrorAction Stop
        Write-Host "  ⊘ Group already exists, skipping" -ForegroundColor Yellow
        $stats.GroupsSkipped++
        continue
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        # Group doesn't exist, continue with creation
    }
    catch {
        Write-Host "  ✗ Error checking for existing group" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $stats.GroupsFailed++
        continue
    }
    
    # Verify OU exists
    try {
        Get-ADOrganizationalUnit -Identity $group.OU -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  ✗ Target OU does not exist: $($group.OU)" -ForegroundColor Red
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
                Path = $group.OU
            }
            
            New-ADGroup @groupParams
            
            Write-Host "  ✓ Created group: $($group.Name)" -ForegroundColor Green
            $stats.GroupsCreated++
        }
        catch {
            Write-Host "  ✗ Failed to create group" -ForegroundColor Red
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
    Write-Host "✓ All objects created successfully!" -ForegroundColor Green
    Write-Host "  You can now run the Automated-Lab-Changes.ps1 script`n" -ForegroundColor Green
}
elseif ($stats.OUsFailed -gt 0) {
    Write-Host "⚠ Some OUs failed to create" -ForegroundColor Yellow
    Write-Host "  This is normal if parent OUs didn't exist yet" -ForegroundColor Yellow
    Write-Host "  Re-run this script to create remaining OUs" -ForegroundColor Yellow
    Write-Host "  Then accounts and groups will be created`n" -ForegroundColor Yellow
}
else {
    Write-Host "⚠ Some objects failed to create" -ForegroundColor Yellow
    Write-Host "  Review errors above and re-run script`n" -ForegroundColor Yellow
}

# Log file suggestion
if (-not $WhatIf) {
    $logSuggestion = ".\New-ADFoundationObjects.ps1 | Tee-Object -FilePath 'C:\Temp\AD-Foundation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log'"
    Write-Host "TIP: To save output to a log file, run:" -ForegroundColor Cyan
    Write-Host "  $logSuggestion`n" -ForegroundColor Gray
}