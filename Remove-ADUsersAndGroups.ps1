<#
.SYNOPSIS
    Removes all users and groups from Semperis DSP lab to allow recreation
.DESCRIPTION
    Deletes users from OU=Employees and groups from OU=Groups and OU=Departments
    Does NOT delete admin/service accounts or computers
#>

param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================================="  -ForegroundColor Red
Write-Host "        AD Cleanup Script - DELETE Users & Groups" -ForegroundColor Red
Write-Host "==============================================================" -ForegroundColor Red
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($WhatIf) { 
    Write-Host "MODE: WHATIF (no changes will be made)" -ForegroundColor Yellow 
}
else {
    Write-Host "WARNING: This will DELETE objects!" -ForegroundColor Red
}
Write-Host "==============================================================`n" -ForegroundColor Red

# Get domain DN
try {
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    Write-Host "Connected to domain: $($domain.DNSRoot)" -ForegroundColor Green
}
catch {
    Write-Host "Could not connect to domain" -ForegroundColor Red
    exit 1
}

$stats = @{
    UsersDeleted = 0
    GroupsDeleted = 0
    Errors = 0
}

# ============================================================
# DELETE REGULAR USERS (OU=Employees)
# ============================================================
Write-Host "`n=============================================================="  -ForegroundColor Cyan
Write-Host "Deleting Regular Users" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

$employeesOU = "OU=Employees,OU=_SemperisDSP,$domainDN"

try {
    $users = Get-ADUser -Filter * -SearchBase $employeesOU -SearchScope Subtree
    Write-Host "Found $($users.Count) users to delete" -ForegroundColor Yellow
    
    foreach ($user in $users) {
        Write-Host "  Deleting: $($user.SamAccountName)" -ForegroundColor White
        
        if (-not $WhatIf) {
            try {
                Remove-ADUser -Identity $user.SamAccountName -Confirm:$false
                $stats.UsersDeleted++
            }
            catch {
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
                $stats.Errors++
            }
        }
        else {
            Write-Host "    [WHATIF] Would delete user" -ForegroundColor Cyan
            $stats.UsersDeleted++
        }
    }
}
catch {
    Write-Host "Error processing users: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# DELETE GROUPS (OU=Groups and OU=Departments)
# ============================================================
Write-Host "`n=============================================================="  -ForegroundColor Cyan
Write-Host "Deleting Groups" -ForegroundColor Cyan
Write-Host "==============================================================`n" -ForegroundColor Cyan

$groupOUs = @(
    "OU=Groups,OU=_SemperisDSP,$domainDN",
    "OU=Departments,OU=_SemperisDSP,$domainDN",
    "OU=Confidential,OU=_SemperisDSP,$domainDN"
)

foreach ($groupOU in $groupOUs) {
    
    Write-Host "`nProcessing: $groupOU" -ForegroundColor Cyan
    
    try {
        $groups = Get-ADGroup -Filter * -SearchBase $groupOU -SearchScope Subtree
        Write-Host "Found $($groups.Count) groups to delete" -ForegroundColor Yellow
        
        foreach ($group in $groups) {
            Write-Host "  Deleting: $($group.Name)" -ForegroundColor White
            
            if (-not $WhatIf) {
                try {
                    Remove-ADGroup -Identity $group.SamAccountName -Confirm:$false
                    $stats.GroupsDeleted++
                }
                catch {
                    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
                    $stats.Errors++
                }
            }
            else {
                Write-Host "    [WHATIF] Would delete group" -ForegroundColor Cyan
                $stats.GroupsDeleted++
            }
        }
    }
    catch {
        Write-Host "Error processing groups in $groupOU : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Also delete tier administrative groups
Write-Host "`nDeleting Tier Administrative Groups..." -ForegroundColor Cyan

$tierGroupOUs = @(
    "OU=Groups,OU=Tier0,OU=Administrative,OU=_SemperisDSP,$domainDN"
)

foreach ($tierOU in $tierGroupOUs) {
    try {
        $groups = Get-ADGroup -Filter * -SearchBase $tierOU -SearchScope Subtree
        Write-Host "Found $($groups.Count) tier groups to delete in $tierOU" -ForegroundColor Yellow
        
        foreach ($group in $groups) {
            Write-Host "  Deleting: $($group.Name)" -ForegroundColor White
            
            if (-not $WhatIf) {
                try {
                    Remove-ADGroup -Identity $group.SamAccountName -Confirm:$false
                    $stats.GroupsDeleted++
                }
                catch {
                    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
                    $stats.Errors++
                }
            }
            else {
                Write-Host "    [WHATIF] Would delete group" -ForegroundColor Cyan
                $stats.GroupsDeleted++
            }
        }
    }
    catch {
        Write-Host "OU not found or error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================================
# SUMMARY
# ============================================================
Write-Host "`n=============================================================="  -ForegroundColor Green
Write-Host "                    SUMMARY" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "Users Deleted:  $($stats.UsersDeleted)" -ForegroundColor $(if ($stats.UsersDeleted -gt 0) { "Yellow" } else { "White" })
Write-Host "Groups Deleted: $($stats.GroupsDeleted)" -ForegroundColor $(if ($stats.GroupsDeleted -gt 0) { "Yellow" } else { "White" })
Write-Host "Errors:         $($stats.Errors)" -ForegroundColor $(if ($stats.Errors -gt 0) { "Red" } else { "Green" })
Write-Host "==============================================================`n" -ForegroundColor Green

if ($WhatIf) {
    Write-Host "This was a WHATIF run - no changes were made" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf to actually delete objects`n" -ForegroundColor Yellow
}
else {
    Write-Host "Cleanup complete!" -ForegroundColor Green
    Write-Host "You can now run the foundation script to recreate groups`n" -ForegroundColor Green
}