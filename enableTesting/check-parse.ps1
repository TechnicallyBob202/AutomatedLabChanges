$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    'c:\GitHub\AutomatedLabChanges\enableTesting\Invoke-AutomatedLabChanges.ps1',
    [ref]$null,
    [ref]$errors
)
if ($errors.Count -eq 0) {
    Write-Host "No parse errors" -ForegroundColor Green
} else {
    $errors | ForEach-Object { Write-Host $_.ToString() -ForegroundColor Red }
}
