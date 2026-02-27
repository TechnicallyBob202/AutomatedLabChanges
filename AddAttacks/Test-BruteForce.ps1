# Test-BruteForce.ps1
# Run this manually on the member server to verify bad-password attempts generate
# 4625 events and trigger DSP brute force detection.
# Tweak variables to match your environment.

$targetUser  = "E304974"        # sAMAccountName of the account to hammer
$domain      = "d3.lab"         # domain DNS name
$netbios     = "D3"             # NetBIOS domain name (forces NTLM, generates 4625 not 4771)
$dcName      = "dc1.d3.lab"     # DC hostname for the UNC path
$attempts    = 50               # should exceed lockout threshold

Write-Host "Starting $attempts bad-password attempts against '$netbios\$targetUser'..."
Write-Host "(using net use to force NTLM -> 4625 events)"
Write-Host ""

1..$attempts | ForEach-Object {
    Write-Host "  attempt $_ "  -NoNewline
    net use \\$dcName\netlogon /user:"$netbios\$targetUser" "WrongPassword!$_" > $null 2>&1
    net use \\$dcName\netlogon /delete > $null 2>&1
    Write-Host "done"
}

Write-Host ""
Write-Host "Done. Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List