$file = 'c:\GitHub\AutomatedLabChanges\enableTesting\Invoke-AutomatedLabChanges.ps1'
$lines = [System.Collections.Generic.List[string]](Get-Content $file)

function Replace-Range {
    param([System.Collections.Generic.List[string]]$list, [int]$start, [int]$end, [string[]]$newLines)
    # start/end are 1-indexed
    $idx = $start - 1
    $count = $end - $start + 1
    $list.RemoveRange($idx, $count)
    [array]::Reverse($newLines)
    foreach ($l in $newLines) { $list.Insert($idx, $l) }
}

# ── svc-pam (1211-1219) ────────────────────────────────────────────────────
Replace-Range $lines 1211 1219 @(
    '            try {',
    '                Invoke-Command -ComputerName $dcName -Credential $serviceAccountCredential -ArgumentList $pamGroup, $userToAction.DistinguishedName -ScriptBlock {',
    '                    param($group, $userDN)',
    '                    Add-ADGroupMember -Identity $group -Members $userDN',
    '                }',
    '                Write-Host "    + svc-pam added user: $($userToAction.SamAccountName) to $pamGroup"',
    '            }',
    '            catch {',
    '                #not worth exiting',
    '                Write-Host "    - svc-pam could not add user: $($userToAction.SamAccountName) to $pamGroup" -ForegroundColor Red',
    '            }'
)

# ── svc-offboarding (1179-1190) ───────────────────────────────────────────
Replace-Range $lines 1179 1190 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serviceAccountCredential -ArgumentList $userToAction.DistinguishedName, $ouEmployeesExpired -ScriptBlock {',
    '                        param($userDN, $targetPath)',
    '                        Set-ADUser -Identity $userDN -Enabled $False',
    '                        Move-ADObject -Identity $userDN -TargetPath $targetPath',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "    + svc-offboarding disabled: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "    - svc-offboarding could not disable: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── svc-callmanager (1148-1158) ───────────────────────────────────────────
Replace-Range $lines 1148 1158 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serviceAccountCredential -ArgumentList $userToAction.DistinguishedName, $userIPPhone -ScriptBlock {',
    '                        param($userDN, $phone)',
    '                        Set-ADUser -Identity $userDN -Replace @{ipPhone = $phone}',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "    + svc-callmanager updated: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "    - svc-callmanager could not update: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── groupNewMember Add-ADGroupMember (1105-1115) ──────────────────────────
Replace-Range $lines 1105 1115 @(
    '                    try {',
    '                        Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $groupToUpdate.DistinguishedName, $serverToAction.DistinguishedName -ScriptBlock {',
    '                            param($groupDN, $serverDN)',
    '                            Add-ADGroupMember -Identity $groupDN -Members $serverDN',
    '                        }',
    '                        if ($showAllActions -eq $True) {',
    '                            Write-Host "      + added server: $($serverToAction.Name) to $($groupToUpdate.Name)"',
    '                        }',
    '                    }',
    '                    catch {',
    '                        #not worth exiting',
    '                        Write-Host "      - could not add:  $($serverToAction.Name) to $($groupToUpdate.Name)" -ForegroundColor Red',
    '                    }'
)

# ── computerNew Add-ADGroupMember (1081-1086) ─────────────────────────────
Replace-Range $lines 1081 1086 @(
    '            try {',
    '                Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $serverGroup, $computerName -ScriptBlock {',
    '                    param($group, $name)',
    '                    Add-ADGroupMember -Identity $group -Members "$name$"',
    '                }',
    '            }',
    '            catch {',
    '                Write-Host "            - server could not be added to server group" -ForegroundColor Red',
    '            }'
)

# ── computerNew New-ADGroup (line 1075) ───────────────────────────────────
Replace-Range $lines 1075 1075 @(
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $serverGroup, $ouGroups -ScriptBlock {',
    '                        param($groupName, $path)',
    '                        New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $path',
    '                    }'
)

# ── computerNew New-ADComputer (1050-1067) ───────────────────────────────
Replace-Range $lines 1050 1067 @(
    '            try {',
    '                Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $computerName, $computerDNS, $ouAppPath, $osVersion, "$appName $appEnvserver" -ScriptBlock {',
    '                    param($name, $dns, $path, $os, $desc)',
    '                    New-ADComputer -Name $name -SAMAccountName $name -DNSHostName $dns -Path $path -OperatingSystem $os -Description $desc',
    '                }',
    '                $serverGroup = "$appName-$appEnv-Servers"',
    '                Start-Sleep -Milliseconds 500',
    '                Write-Host "          + created server: $computerName"',
    '            }',
    '            catch {',
    '                Write-Host "          - server could not be created: $computerName" -ForegroundColor Red',
    '                if ($continueOnError -eq $false) {',
    '                    Write-Host "          - continue on error set to false, exiting" -ForegroundColor Red',
    '                    Exit',
    '                }',
    '            }'
)

# ── computerNew New-ADOrganizationalUnit (line 1016) ─────────────────────
Replace-Range $lines 1016 1016 @(
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $appName, $ouServers -ScriptBlock {',
    '                        param($name, $path)',
    '                        New-ADOrganizationalUnit -Name $name -Path $path',
    '                    }'
)

# ── computerEnable in ServerAction (985-994) ──────────────────────────────
Replace-Range $lines 985 994 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADComputer -Identity $dn -Enabled $True',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + server enabled: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    Write-Host "      - could not enable: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

# ── computerDisable in ServerAction (958-968) ─────────────────────────────
Replace-Range $lines 958 968 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADComputer -Identity $dn -Enabled $False',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + server disabled: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not disable server: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

# ── computerDelete in ServerAction (931-941) ──────────────────────────────
Replace-Range $lines 931 941 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $serverCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Remove-ADComputer -Identity $dn -Confirm:$False',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + server deleted: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not delete server: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

# ── userUpdateDescription (891-902) ───────────────────────────────────────
Replace-Range $lines 891 902 @(
    '                try {',
    '                    $userToActionDescription = $userToAction.Description + '' I''',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName, $userToActionDescription -ScriptBlock {',
    '                        param($dn, $desc)',
    '                        Set-ADUser -Identity $dn -Description $desc',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + changed description: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not change description: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── updateConfidentialGroup (872-880) ─────────────────────────────────────
Replace-Range $lines 872 880 @(
    '            try {',
    '                Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $pamGroup, $userToAction.DistinguishedName -ScriptBlock {',
    '                    param($group, $userDN)',
    '                    Add-ADGroupMember -Identity $group -Members $userDN',
    '                }',
    '                Write-Host "    + added user: $($userToAction.SamAccountName) to $pamGroup"',
    '            }',
    '            catch {',
    '                #not worth exiting',
    '                Write-Host "    - could not add user: $($userToAction.SamAccountName) to $pamGroup" -ForegroundColor Red',
    '            }'
)

# ── passwordResetInDescription (842-853) ──────────────────────────────────
Replace-Range $lines 842 853 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName, $userPassword -ScriptBlock {',
    '                        param($dn, $pwd)',
    '                        Set-ADAccountPassword -Identity $dn -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $pwd -Force)',
    '                        Set-ADUser -Identity $dn -Description "Password: $pwd"',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + changed password and updated user description: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not set password in description: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── passwordReset (814-824) ───────────────────────────────────────────────
Replace-Range $lines 814 824 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName, $userPassword -ScriptBlock {',
    '                        param($dn, $pwd)',
    '                        Set-ADAccountPassword -Identity $dn -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $pwd -Force)',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + changed password: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not change password: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── passwordAtNextLogon (787-797) ─────────────────────────────────────────
Replace-Range $lines 787 797 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADUser -Identity $dn -ChangePasswordAtLogon $True',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + change password at next logon set: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not set change password at next logon: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── passwordAbnormalRefresh (759-771) ─────────────────────────────────────
Replace-Range $lines 759 771 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADUser -Identity $dn -ChangePasswordAtLogon $True',
    '                        Start-Sleep -Seconds 10',
    '                        Set-ADUser -Identity $dn -ChangePasswordAtLogon $False',
    '                    }',
    '                    Write-Host "      + abnormaly refreshed password: $($userToAction.SamAccountName)"',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not abnormaly refresh password: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── computerEnable in HelpdeskAction (733-743) ────────────────────────────
Replace-Range $lines 733 743 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADComputer -Identity $dn -Enabled $True',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + enabled computer: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not enable computer: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

# ── computerDisable in HelpdeskAction (707-717) ───────────────────────────
Replace-Range $lines 707 717 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADComputer -Identity $dn -Enabled $False',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + disabled computer: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not disable computer: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

# ── userEnable in HelpdeskAction (681-691) ────────────────────────────────
Replace-Range $lines 681 691 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADUser -Identity $dn -Enabled $True',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + enabled user: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not enable user: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── userDisable in HelpdeskAction (656-666) ───────────────────────────────
Replace-Range $lines 656 666 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Set-ADUser -Identity $dn -Enabled $False',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + disabled user: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not disable user: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── setServerSPN (line 625) ───────────────────────────────────────────────
Replace-Range $lines 625 625 @(
    '                    Invoke-Command -ComputerName $dcName -Credential $domainAdminCredential -ArgumentList $computerToAction.DistinguishedName, $servicePrincipalName -ScriptBlock {',
    '                        param($dn, $spn)',
    '                        Set-ADComputer -Identity $dn -ServicePrincipalNames @{Add = $spn}',
    '                    }'
)

# ── newSubnet (lines 590-608) ─────────────────────────────────────────────
Replace-Range $lines 590 608 @(
    '            try {',
    '                $randomIP = "{0}.{1}.{2}.{3}" -f (Get-Random -Minimum 1 -Maximum 254),',
    '                (Get-Random -Minimum 0 -Maximum 255),',
    '                (Get-Random -Minimum 0 -Maximum 255),',
    '                (Get-Random -Minimum 1 -Maximum 254)',
    '                $randomIpNetmask = $randomIP -replace "\d{1,3}$", "0/24"',
    '                $randomIpNetmaskLocation = "Subnet: $randomIpNetmask"',
    '                Invoke-Command -ComputerName $dcName -Credential $domainAdminCredential -ArgumentList $randomIpNetmask, $randomIpNetmaskLocation -ScriptBlock {',
    '                    param($subnet, $location)',
    '                    New-ADReplicationSubnet -Name $subnet -Location $location',
    '                }',
    '                if ($showAllActions -eq $true) {',
    '                    Write-Host "      + created subnet: $randomIPNetMask"',
    '                }',
    '            }',
    '            catch {',
    '                Write-Host "      - could not create subnet: $randomIPNetMask" -ForegroundColor Red',
    '            }'
)

# ── updateDepartmentGroup Add-ADGroupMember (261-273) ─────────────────────
Replace-Range $lines 261 273 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $deptRoleGroupName, $uUser.DistinguishedName -ScriptBlock {',
    '                        param($group, $userDN)',
    '                        Add-ADGroupMember -Identity $group -Members $userDN',
    '                    }',
    '                    Write-Host "      + user added to new department group: $deptRoleGroupName"',
    '                }',
    '                catch {',
    '                    Write-Host "      - could not add user to new department group: $deptRoleGroupName" -ForegroundColor Red',
    '                    if ($continueOnError -eq $false) {',
    '                        Write-Host "      - continue on error set to false, exiting" -ForegroundColor Red',
    '                        Exit',
    '                    }',
    '                }'
)

# ── updateDepartmentGroup Set-ADUser (245-259) ────────────────────────────
Replace-Range $lines 245 259 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $uUser.DistinguishedName, $uJobTitle, $uDepartmentName -ScriptBlock {',
    '                        param($dn, $title, $dept)',
    '                        Set-ADUser -Identity $dn -Title $title -Department $dept -Description $title',
    '                    }',
    '                    Write-Host "      + user department updated: $uDepartmentName"',
    '                    Write-Host "      + user description updated: $uJobTitle"',
    '                    Write-Host "      + user job title updated: $uJobTitle"',
    '                }',
    '                catch {',
    '                    Write-Host "      - could not update department and job title" -ForegroundColor Red',
    '                    if ($continueOnError -eq $false) {',
    '                        Write-Host "  - continue on error set to false, exiting" -ForegroundColor Red',
    '                        Exit',
    '                    }',
    '                }'
)

# ── updateDepartmentGroup Remove-ADGroupMember (line 232) ─────────────────
Replace-Range $lines 232 232 @(
    '                            Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $group.Name, $uUser.DistinguishedName -ScriptBlock {',
    '                                param($groupName, $userDN)',
    '                                Remove-ADGroupMember -Identity $groupName -Members $userDN -Confirm:$false',
    '                            }'
)

# ── userDisable in DesktopAction (191-202) ────────────────────────────────
Replace-Range $lines 191 202 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $userToAction.DistinguishedName, $ouEmployeesExpired -ScriptBlock {',
    '                        param($dn, $targetPath)',
    '                        Set-ADUser -Identity $dn -Enabled $False',
    '                        Move-ADObject -Identity $dn -TargetPath $targetPath',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "    + disabled user: $($userToAction.SamAccountName)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "    + could not disable user: $($userToAction.SamAccountName)" -ForegroundColor Red',
    '                }'
)

# ── computerNew in DesktopAction (128-142) ────────────────────────────────
Replace-Range $lines 128 142 @(
    '            try {',
    '                Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $computerName, $computerDNS, $computerOS, $computerOSVersion, $ouWorkstationTarget -ScriptBlock {',
    '                    param($name, $dns, $os, $osVer, $path)',
    '                    New-ADComputer -Name $name -DNSHostName $dns -Description $dns -OperatingSystem $os -OperatingSystemVersion $osVer -Enabled $true -Path $path',
    '                }',
    '                if ($showAllActions -eq $True) {',
    '                    Write-Host "  + created computer: $computerName"',
    '                }',
    '            }',
    '            catch {',
    '                Write-Host "  - could not create computer: $computerName" -ForegroundColor Red',
    '                if ($continueOnError -eq $false) {',
    '                    Write-Host " - continue on error set to false, exiting" -ForegroundColor Red',
    '                    Exit',
    '                }',
    '            }'
)

# ── computerDisable in DesktopAction (76-87) ──────────────────────────────
Replace-Range $lines 76 87 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $computerToAction.DistinguishedName, $ouWorkstationsExpired -ScriptBlock {',
    '                        param($dn, $targetPath)',
    '                        Set-ADComputer -Identity $dn -Enabled $False',
    '                        Move-ADObject -Identity $dn -TargetPath $targetPath',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + disabled computer: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting',
    '                    Write-Host "      - could not disable computer: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

# ── computerDelete in DesktopAction (50-60) ───────────────────────────────
Replace-Range $lines 50 60 @(
    '                try {',
    '                    Invoke-Command -ComputerName $dcName -Credential $desktopCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {',
    '                        param($dn)',
    '                        Remove-ADComputer -Identity $dn -Confirm:$false',
    '                    }',
    '                    if ($showAllActions -eq $True) {',
    '                        Write-Host "      + deleted computer: $($computerToAction.Name)"',
    '                    }',
    '                }',
    '                catch {',
    '                    #not worth exiting for',
    '                    Write-Host "      - could not delete computer: $($computerToAction.Name)" -ForegroundColor Red',
    '                }'
)

Set-Content $file $lines
Write-Host "Done. $($lines.Count) lines written."
