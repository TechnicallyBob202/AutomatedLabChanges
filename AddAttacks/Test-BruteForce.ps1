# Test-BruteForce.ps1
# Single attempt - get this working first, then we'll loop it.

$targetUser = "E304974"
$netbios    = "D3"
$domain     = "d3.lab"
$runasUser  = "D3\domain-admin"
$runasPass  = "superSECURE!"

$runasPassSecure = ConvertTo-SecureString $runasPass -AsPlainText -Force
$runasCred = New-Object System.Management.Automation.PSCredential($runasUser, $runasPassSecure)

# find all DCs in the domain
$dcs = (Get-ADDomainController -Filter * -Server $domain).HostName
Write-Host "DCs found: $($dcs -join ', ')"
Write-Host ""

Write-Host "Single bad-password attempt against '$netbios\$targetUser'..."
$timeBefore = Get-Date

foreach ($dc in $dcs) {
    Write-Host "  -> trying via $dc"
    Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c net use \\$dc\netlogon /user:$netbios\$targetUser WrongPassword123" `
        -Credential $runasCred `
        -WindowStyle Hidden `
        -Wait
}

Write-Host ""
Write-Host "Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List

Write-Host "Searching Security log on all DCs for 4625/4771 events since $timeBefore..."
Write-Host ""
foreach ($dc in $dcs) {
    Write-Host "-- $dc --"
    try {
        $events = Get-WinEvent -ComputerName $dc -Credential $runasCred -FilterHashtable @{
            LogName   = 'Security'
            Id        = @(4625, 4771)
            StartTime = $timeBefore
        } -ErrorAction Stop | Where-Object { $_.Message -match $targetUser }

        if ($events) {
            $events | ForEach-Object {
                Write-Host "  EventID=$($_.Id) Time=$($_.TimeCreated)"
            }
        } else {
            Write-Host "  no matching events found"
        }
    }
    catch {
        Write-Host "  could not query: $($_.Exception.Message)" -ForegroundColor Red
    }
}