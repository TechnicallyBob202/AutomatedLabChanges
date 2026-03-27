# Run this on DUMPSTERFIRE to replicate action/service account group memberships from D3
# Accounts must already exist - this only adds group memberships

$accountGroups = @{
    "domain-admin"    = @("T0_Admins_Global_RG", "Domain Admins", "Enterprise Admins")
    "rogue-admin"     = @("T0_Admins_Global_RG")
    "network-admin"   = @("T1_NetworkAdmin_Global_RG")
    "server-admin"    = @("T1_ServerAdmin_Global_RG", "Account Operators", "Remote Management Users")
    "desktop-admin"   = @("T2_DesktopSupport_Global_RG", "Account Operators", "Remote Management Users")
    "helpdesk-admin"  = @("T2_HelpDesk_RG", "Account Operators", "Remote Management Users")
    "cloud-admin"     = @("TC_CloudAdmins_RG")
    "vip-admin"       = @("T2_VIP_Support_RG")
    "svc-callmanager" = @("Account Operators", "Remote Management Users")
    "svc-onboarding"  = @("Account Operators", "Remote Management Users")
    "svc-offboarding" = @("Account Operators", "Remote Management Users")
    "svc-pam"         = @("Account Operators", "Enterprise Admins", "Remote Management Users")
}

foreach ($account in $accountGroups.Keys | Sort-Object) {
    $user = Get-ADUser -Filter { SamAccountName -eq $account }
    if ($null -eq $user) {
        Write-Host "=== $account === NOT FOUND - skipping" -ForegroundColor Red
        continue
    }

    Write-Host "=== $account ===" -ForegroundColor Cyan
    foreach ($group in $accountGroups[$account]) {
        try {
            Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
            Write-Host "  + added to $group" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -match "already a member") {
                Write-Host "  ~ already in $group" -ForegroundColor Yellow
            }
            else {
                Write-Host "  - FAILED to add to $group : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
