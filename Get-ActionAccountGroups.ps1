# Run this on D3 to enumerate group memberships for all action/service accounts
# used by Invoke-AutomatedLabChanges

$accounts = @(
    # Action accounts
    "domain-admin",
    "rogue-admin",
    "network-admin",
    "server-admin",
    "desktop-admin",
    "helpdesk-admin",
    "cloud-admin",
    "vip-admin",
    # Service accounts
    "svc-callmanager",
    "svc-onboarding",
    "svc-offboarding",
    "svc-pam"
)

foreach ($account in $accounts) {
    $user = Get-ADUser -Filter { SamAccountName -eq $account } -Properties MemberOf
    if ($null -ne $user) {
        Write-Host "`n=== $account ===" -ForegroundColor Cyan
        if ($user.MemberOf.Count -eq 0) {
            Write-Host "  (Domain Users only)"
        }
        else {
            $user.MemberOf | ForEach-Object {
                $groupName = ($_ -split ',')[0] -replace '^CN=', ''
                Write-Host "  $groupName"
            }
        }
    }
    else {
        Write-Host "`n=== $account ===" -ForegroundColor Yellow
        Write-Host "  NOT FOUND" -ForegroundColor Red
    }
}
