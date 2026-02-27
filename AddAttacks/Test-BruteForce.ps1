# Test-BruteForce.ps1
# Loop version - confirmed single attempt works, now hammering for lockout + DSP alert.

$targetUser = "E304974"
$netbios    = "D3"
$domain     = "d3.lab"
$runasUser  = "D3\domain-admin"
$runasPass  = "superSECURE!"
$attempts   = 20

$runasPassSecure = ConvertTo-SecureString $runasPass -AsPlainText -Force
$runasCred = New-Object System.Management.Automation.PSCredential($runasUser, $runasPassSecure)

$dcs = (Get-ADDomainController -Filter * -Server $domain).HostName
Write-Host "DCs found: $($dcs -join ', ')"
Write-Host "Starting $attempts attempts against '$netbios\$targetUser'..."
Write-Host ""

$timeBefore = Get-Date

1..$attempts | ForEach-Object {
    $i = $_
    foreach ($dc in $dcs) {
        Start-Process -FilePath "cmd.exe" `
            -ArgumentList "/c net use \\$dc\netlogon /user:$netbios\$targetUser WrongPassword$i" `
            -Credential $runasCred `
            -WindowStyle Hidden `
            -Wait
    }
    Write-Host "  attempt $i done"
}

Write-Host ""
Write-Host "Checking AD status..."
Get-ADUser -Identity $targetUser -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Select-Object SamAccountName, LockedOut, BadLogonCount, LastBadPasswordAttempt |
    Format-List

Write-Host "Searching Security log on all DCs for 4625/4771 events since $timeBefore..."
foreach ($dc in $dcs) {
    Write-Host "-- $dc --"
    try {
        $events = Get-WinEvent -ComputerName $dc -Credential $runasCred -FilterHashtable @{
            LogName   = 'Security'
            Id        = @(4625, 4771)
            StartTime = $timeBefore
        } -ErrorAction Stop | Where-Object { $_.Message -match $targetUser }

        if ($events) {
            Write-Host "  $($events.Count) event(s) found"
            $events | ForEach-Object { Write-Host "  EventID=$($_.Id) Time=$($_.TimeCreated)" }
        } else {
            Write-Host "  no matching events found"
        }
    }
    catch {
        Write-Host "  could not query: $($_.Exception.Message)" -ForegroundColor Red
    }
}