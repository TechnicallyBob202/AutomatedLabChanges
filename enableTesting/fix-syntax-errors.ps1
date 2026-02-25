$file = 'c:\GitHub\AutomatedLabChanges\enableTesting\Invoke-AutomatedLabChanges.ps1'
$lines = [System.Collections.Generic.List[string]](Get-Content $file)

function Replace-Range {
    param([System.Collections.Generic.List[string]]$list, [int]$start, [int]$end, [string[]]$newLines)
    $idx = $start - 1
    $count = $end - $start + 1
    $list.RemoveRange($idx, $count)
    [array]::Reverse($newLines)
    foreach ($l in $newLines) { $list.Insert($idx, $l) }
}

# Fix 2: New-ADGroup inner try/catch (lines 1111-1121)
# Old line 1113 (New-ADGroup -Credential) left behind; add missing } before catch
Replace-Range $lines 1111 1121 @(
    '			catch {',
    '				try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $serverGroup, $ouGroups -ScriptBlock {',
    '                        param($groupName, $path)',
    '                        New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $path',
    '                    }',
    '				}',
    '				catch {',
    '					# Group may already exist or other error',
    '				}',
    '			}'
)

# Fix 1: New-ADOrganizationalUnit inner try/catch (lines 1051-1061)
# Old line 1053 (New-ADOrganizationalUnit -Credential) left behind; add missing } before catch
Replace-Range $lines 1051 1061 @(
    '            catch {',
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $appName, $ouServers -ScriptBlock {',
    '                        param($name, $path)',
    '                        New-ADOrganizationalUnit -Name $name -Path $path',
    '                    }',
    '                }',
    '                catch {',
    '                    # OU may already exist or other error',
    '                }',
    '            }'
)

Set-Content $file $lines
Write-Host "Done. $($lines.Count) lines written."
