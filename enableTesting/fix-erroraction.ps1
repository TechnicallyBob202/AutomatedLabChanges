$file = 'c:\GitHub\AutomatedLabChanges\enableTesting\Invoke-AutomatedLabChanges.ps1'
$content = Get-Content $file -Raw
$updated = $content -replace 'Invoke-Command -ComputerName \$dcName', 'Invoke-Command -ComputerName $dcName -ErrorAction Stop'
Set-Content $file $updated -NoNewline
$count = ([regex]::Matches($updated, 'Invoke-Command -ComputerName \$dcName -ErrorAction Stop')).Count
Write-Host "Done. $count Invoke-Command calls updated."
