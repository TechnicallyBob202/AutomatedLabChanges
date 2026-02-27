# Test-BruteForce.ps1
# Single attempt - get this working first, then we'll loop it.
# runas /netonly creates a fresh logon session with no Kerberos tickets,
# forcing net use to authenticate via NTLM against the DC.

$targetUser = "E304974"
$netbios    = "D3"
$dcName     = "dc1.d3.lab"

# A real domain account to spawn the process as - just needs to exist and be able to log on
# /netonly means local execution uses YOUR current creds, but network auth uses these creds
# The password here doesn't matter for the net use attempt - it's the target user's password that fails
$runasUser  = "D3\domain-admin"
$runasPass  = "superSECURE!"

Write-Host "Single bad-password attempt against '$netbios\$targetUser' via '$dcName'..."
Write-Host ""

$runasPassSecure = ConvertTo-SecureString $runasPass -AsPlainText -Force
$runasCred = New-Object System.Management.Automation.PSCredential($runasUser, $runasPassSecure)

Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c net use \\$dcName\netlogon /user:$netbios\$targetUser WrongPassword123" `
    -Credential $runasCred `
    -WindowStyle Hidden `
    -Wait

Write-Host ""
Write-Host "Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List