# Test-BruteForce.ps1
# Run this manually on the member server.
# Uses Start-Process with -Credential to run each net use in an isolated session
# that has no cached Kerberos tickets, forcing a fresh NTLM auth attempt each time.
# Tweak variables to match your environment.

$targetUser    = "E304974"      # sAMAccountName to hammer
$netbios       = "D3"           # NetBIOS domain name
$dcName        = "dc1.d3.lab"   # DC to target
$attempts      = 50             # should exceed lockout threshold

# The script runs net use as a low-privilege local account with no domain tickets.
# This forces each attempt to authenticate via NTLM against the DC.
# Use any local account - even a freshly created one with no permissions.
# The account just needs to exist locally so Start-Process can impersonate it.
$localUser     = ".\brutetest"          # local account to run net use as (no domain tickets)
$localPass     = "LocalPass123!"        # password for that local account

# Create the local account if it doesn't exist
if (-not (Get-LocalUser -Name "brutetest" -ErrorAction SilentlyContinue)) {
    $lp = ConvertTo-SecureString $localPass -AsPlainText -Force
    New-LocalUser -Name "brutetest" -Password $lp -PasswordNeverExpires -Description "Temp brute force test account"
    Write-Host "  + created local account 'brutetest'"
}

$localCred = New-Object System.Management.Automation.PSCredential($localUser, (ConvertTo-SecureString $localPass -AsPlainText -Force))

Write-Host "Starting $attempts bad-password attempts against '$netbios\$targetUser' via '$dcName'..."
Write-Host ""

1..$attempts | ForEach-Object {
    $badPass = "WrongPassword!$_"
    # run net use in isolated process with no domain tickets
    $proc = Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c net use \\$dcName\netlogon /user:$netbios\$targetUser $badPass > nul 2>&1" `
        -Credential $localCred `
        -WindowStyle Hidden `
        -PassThru `
        -Wait
    Write-Host "  attempt $_  : exit=$($proc.ExitCode)"
}

Write-Host ""
Write-Host "Done. Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List

# Clean up local test account
Remove-LocalUser -Name "brutetest" -ErrorAction SilentlyContinue
Write-Host "  + removed local account 'brutetest'"