# Test-BruteForce.ps1
# Run this manually on the member server to verify bad-password attempts generate
# 4625 events and trigger DSP brute force detection.
# Tweak variables to match your environment.

$targetUser = "E304974"     # sAMAccountName of the account to hammer
$netbios    = "D3"          # NetBIOS domain name - NETBIOS\user format forces NTLM (4625) not Kerberos (4771)
$domain     = "d3.lab"      # domain DNS name for PrincipalContext
$dcName     = "dc1.d3.lab"  # explicit DC - ensures auth goes to a specific DC, not random
$attempts   = 50            # should exceed lockout threshold

# NETBIOS\user format is the key:
#   bare sAMAccountName  -> Account Domain blank in 4625, may not trigger DSP
#   user@domain (UPN)    -> Kerberos, generates 4771 not 4625
#   NETBIOS\user         -> forces NTLM, generates 4625 with populated Account Domain
$targetFQN = "$netbios\$targetUser"

Add-Type -AssemblyName System.DirectoryServices.AccountManagement

# specify DC explicitly so all attempts hit the same DC and events are co-located
$ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
    [System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain, $dcName
)

Write-Host "Starting $attempts bad-password attempts against '$targetFQN' via '$dcName'..."
Write-Host ""

1..$attempts | ForEach-Object {
    $result = $false
    try { $result = $ctx.ValidateCredentials($targetFQN, "WrongPassword!$_") } catch { }
    Write-Host "  attempt $_  : $result"
}

$ctx.Dispose()

Write-Host ""
Write-Host "Done. Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List