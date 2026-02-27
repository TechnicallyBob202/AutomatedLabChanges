# Test-BruteForce.ps1
# Run this manually on the server to verify bad-password attempts generate lockout + security events.
# Tweak $targetUser and $domain to match your environment.

$targetUser = "E304974"        # sAMAccountName of the account to hammer
$domain     = "d3.lab"         # domain DNS name
$attempts   = 50               # should exceed lockout threshold

Add-Type -AssemblyName System.DirectoryServices.AccountManagement

$ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
    [System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain
)

Write-Host "Starting $attempts bad-password attempts against '$targetUser' in '$domain'..."

1..$attempts | ForEach-Object {
    $result = $false
    try { $result = $ctx.ValidateCredentials($targetUser, "WrongPassword!$_") } catch { }
    Write-Host "  attempt $_  : $result"
}

$ctx.Dispose()

Write-Host ""
Write-Host "Done. Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List