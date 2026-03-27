param([switch]$TestOnly)

$domainBase = "_DUMPSTERFIRE"
  
#only used if online
$userCountryCodes = "GB,IE,NZ,US"
$offlineUserData = "C:\ProgramData\Semperis_Community\AutomatedLabChanges\Real-ADUser-Data-5000.json"
  
#default password - this is the password that the action accounts use
$passwordDefault = "superSECURE!"
$passwordSecure = ConvertTo-SecureString -String "$passwordDefault" -AsPlainText -Force
  
#maximum number of actions and time between each actions
$actionsWait = 150
$actionsMax = 240 
  
#log file details path 
$logFileDate = Get-Date -Format "yyyy-MM-dd"
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$fLogFile = "$scriptPath\Logs\AutomatedLab-Changes-$logFileDate.log"
  
#extended action display
$showAllActions = $true
  
#import Group Policy Module
Import-Module GroupPolicy
  
  
Function Invoke-DesktopAction {
param(
        [string]$desktopAction
    )
    $accountDesktop = ($actionAccounts | Where-Object { $_.ID -eq "desktop" }).AccountName
    $desktopCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountDesktop, $passwordSecure
        
    $desktopAction = $desktopAction
  
    switch ($desktopAction) {
  
        #deletes a computer if one exists
        computerDelete {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter * -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) {                
                    $computerToAction = $computerToAction | Get-Random -Count 1
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Remove-ADComputer -Identity $dn -Confirm:$false
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + deleted computer: $($computerToAction.Name)"
                    }
                }
                catch {
                    #not worth exiting for
                    Write-Host "      - could not delete computer: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        #disables a computer if one exists
        computerDisable {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $True } -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random -Count 1
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $computerToAction.DistinguishedName, $ouWorkstationsExpired -ScriptBlock {
                        param($dn, $targetPath)
                        Set-ADComputer -Identity $dn -Enabled $False
                        Move-ADObject -Identity $dn -TargetPath $targetPath
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + disabled computer: $($computerToAction.Name)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not disable computer: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        #creates a new computer of differing types, virtual, laptop, workstation, engineering etc
        computerNew {
            $computerType = @("ENG", "FLD", "KSK", "WKS", "VDI")
            $computerType = $computerType | Get-Random
  
            $ouWorkstationTarget = $null
  
            switch ($computerType) {
                ENG {
                    $ouWorkstationTarget = "OU=Engineering,$ouWorkstations"
                }
                FLD {
                    $ouWorkstationTarget = "OU=Field,$ouWorkstations"
                }
                KSK {
                    $ouWorkstationTarget = "OU=Kiosks,$ouWorkstations"
                }
                WKS {
                    $ouWorkstationTarget = $ouWorkstations
                }
                VDI {
                    $ouWorkstationTarget = "OU=VDI,$ouWorkstations"
                }
            }
  
            $computerString = -join ((65..90) | Get-Random -Count 9 | ForEach-Object { [char]$_ })
            $computerStringNumber = (1..99).ForEach({ '{0:D2}' -f $_ })[(Get-Random -Minimum 0 -Maximum 99)]
            
            $computerName = "$computerType-$computerString$computerStringNumber"
            $computerDNS = "$computerName.$domainSuffix"
  
            #all will be this very, because lazy and not real anyway
            $computerOS = "Windows 11 Pro"
            $computerOSVersion = "10.0 (22621)"
  
            try {
                Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $computerName, $computerDNS, $computerOS, $computerOSVersion, $ouWorkstationTarget -ScriptBlock {
                    param($name, $dns, $os, $osVer, $path)
                    New-ADComputer -Name $name -DNSHostName $dns -Description $dns -OperatingSystem $os -OperatingSystemVersion $osVer -Enabled $true -Path $path
                }
                if ($showAllActions -eq $True) {
                    Write-Host "  + created computer: $computerName"
                }
            }
            catch {
                Write-Host "  - could not create computer: $computerName" -ForegroundColor Red
                if ($continueOnError -eq $false) {
                    Write-Host " - continue on error set to false, exiting" -ForegroundColor Red
                    Exit
                }
            }
        }
        #creates a new user, bypassing the onboarding process, bad 
        userNew {
            $userToAction = $null
            $userToAction = New-RealADUser -Credential $desktopCredential
        }
        userNewDesEncryption {           
            try {
                New-RealADUser -allowDES $true -Credential $desktopCredential 
                Write-Host "      + DES encryption allowed"  
            }
            catch {
                #not worth exiting
                Write-Host "      - could create account with DES encryption enabled" -ForegroundColor Red
            }
        }
        userNewReversibleEncryption {
            try {
                
                New-RealADUser -allowReversionEncryption $true -Credential $desktopCredential             
                Write-Host "      + reversible encryption allowed"  
            }
            catch {
                #not worth exiting
                Write-Host "      - could not create an account with reversible encryption allowed" -ForegroundColor Red
            }
        }   
        userNewPasswordNotRequired {
            try {
                
                New-RealADUser -passNotRequired $true -Credential $desktopCredential             
                Write-Host "      + password not required allowed"  
            }
            catch {
                #not worth exiting
                Write-Host "      - could not create an account with password not required allowed" -ForegroundColor Red
            }
        }                          
        #disables a user - skip VIPs
        userDisable {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) {
                    $userToAction = $userToAction | Get-Random -Count 1
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $userToAction.DistinguishedName, $ouEmployeesExpired -ScriptBlock {
                        param($dn, $targetPath)
                        Set-ADUser -Identity $dn -Enabled $False
                        Move-ADObject -Identity $dn -TargetPath $targetPath
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "    + disabled user: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "    + could not disable user: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no enabled users found" -ForegroundColor Yellow
            }
        }
        #updates a department group, looks up the department for a job title then matches the user to the group
        updateDepartmentGroup {
            $uUser = Get-ADUser -Filter { Enabled -eq $True } -SearchBase $ouEmployees -SearchScope OneLevel -Properties MemberOf, Title, Department | Get-Random -Count 1
  
            if ($null -ne $uUser) {
  
                #updated department and job role
                $uDepartment = Get-Random -InputObject ($selectedDepartments | Where-Object { $_.Name -ne "C-Suite" })
                $uDepartmentName = $uDepartment.Name
                $uDepartmentPosition = Get-Random -InputObject $uDepartment.Positions
                $uDepartmentLevel = Get-Random -InputObject $departmentsJobLevels
                $uJobTitle = "$uDepartmentPosition $uDepartmentLevel"
                $deptRoleGroupName = "$uDepartmentName - $uDepartmentPosition"  
  
                #remove old department
  
                Write-Host "    + updating department for user: $($uUser.Name) [$($uUser.SamAccountName)]"
  
                $uUser.MemberOf | ForEach-Object {
                    $group = Get-ADGroup $_ -Properties Name
    
                    if ($group.Name -like "$($uUser.Department)*") {
  
                        try {
                            Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $group.Name, $uUser.DistinguishedName -ScriptBlock {
                                param($groupName, $userDN)
                                Remove-ADGroupMember -Identity $groupName -Members $userDN -Confirm:$false
                            }
                        }
                        catch {
                            Write-Host "      - could not remove user from existing department group: $($group.Name)" -ForegroundColor Red
  
                            if ($continueOnError -eq $false) {
                                Write-Host "      - continue on error set to false, exiting" -ForegroundColor Red                    
                                Exit
                            }            
                        }  
                    }
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $uUser.DistinguishedName, $uJobTitle, $uDepartmentName -ScriptBlock {
                        param($dn, $title, $dept)
                        Set-ADUser -Identity $dn -Title $title -Department $dept -Description $title
                    }
                    Write-Host "      + user department updated: $uDepartmentName"
                    Write-Host "      + user description updated: $uJobTitle"
                    Write-Host "      + user job title updated: $uJobTitle"
                }
                catch {
                    Write-Host "      - could not update department and job title" -ForegroundColor Red
                    if ($continueOnError -eq $false) {
                        Write-Host "  - continue on error set to false, exiting" -ForegroundColor Red
                        Exit
                    }
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $desktopCredential -ArgumentList $deptRoleGroupName, $uUser.DistinguishedName -ScriptBlock {
                        param($group, $userDN)
                        Add-ADGroupMember -Identity $group -Members $userDN
                    }
                    Write-Host "      + user added to new department group: $deptRoleGroupName"
                }
                catch {
                    Write-Host "      - could not add user to new department group: $deptRoleGroupName" -ForegroundColor Red
                    if ($continueOnError -eq $false) {
                        Write-Host "      - continue on error set to false, exiting" -ForegroundColor Red
                        Exit
                    }
                }
  
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }
    }
}
  
Function Invoke-DomainAdminAction {
    param(
        [string]$domainAdminAction
    )
  
    $accountDomainAdmin = ($actionAccounts | Where-Object { $_.ID -eq "domainadmin" }).AccountName
    $domainAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountDomainAdmin, $passwordSecure
        
    switch ($domainAdminAction) {      
          
        #dnsRecordAdd
        dnsRecordAdd {
            $dnsRecordTypes = @("enterpriseapp", "server", "workstation", "generic")
            $dnsRecordType = $dnsRecordTypes | Get-Random
  
  
            $dnsGenericRecords = @("email", "mail", "www", "vpn", "intranet", "sspr", "sharepoint", "hcm", "helpdesk")            
  
            switch ($dnsRecordType) {
                enterpriseapp {
                    $enterpriseApp = $selectedEnterpriseApps | Get-Random
                    $enterpriseAppEnvironment = $enterpriseAppsEnvironments | Get-Random
                    $dnsRecordToCreate = "$($enterpriseApp.ID)$($enterpriseAppEnvironment)"   
                }
                generic {
                    $dnsRecordToCreate = $dnsGenericRecords | Get-Random            
                }
                server {
                    $computerToCheck = $null
                    $computerToCheck = Get-ADComputer -Filter * -SearchBase $ouServers 
                        
                    if ($null -ne $computerToCheck) {
                        if ($computerToCheck.count -gt 1) { 
                            $computerToCheck = $computerToCheck | Get-Random
                        }   
                    }
  
                    $dnsRecordToCreate = $computerToCheck.Name
                }
                workstation { 
                    $computerToCheck = $null
                    $computerToCheck = Get-ADComputer -Filter * -SearchBase $ouWorkstations
                        
                    if ($null -ne $computerToCheck) {
                        if ($computerToCheck.count -gt 1) { 
                            $computerToCheck = $computerToCheck | Get-Random
                        }   
                    }
  
                    $dnsRecordToCreate = $computerToCheck.Name
                }       
            }
            
            $dnsRecordCheck = $null

            $dnsRecordCheck = Invoke-Command -ComputerName $dcName -Credential $domainAdminCredential -ArgumentList $dnsRecordToCreate, $domainSuffix -ScriptBlock {
                param($name, $zone)
                Get-DnsServerResourceRecord -Name $name -ZoneName $zone -RRType A -ErrorAction SilentlyContinue
            }
  
            #create the dns record
            if ($null -eq $dnsRecordCheck) {
  
                Write-Host "      + creating dns record: $dnsRecordToCreate"
  
                $result = Invoke-Command -ComputerName $dcName -ErrorAction Stop -ArgumentList $dnsRecordToCreate, $domainSuffix -Credential $domainAdminCredential -ScriptBlock {
  
                    $dnsRecordToCreate = $args[0]
                    $domainSuffix = $args[1]
  
                    $randomIP = "{0}.{1}.{2}.{3}" -f (Get-Random -Minimum 1 -Maximum 254),
                    (Get-Random -Minimum 0 -Maximum 255),
                    (Get-Random -Minimum 0 -Maximum 255),
                    (Get-Random -Minimum 1 -Maximum 254)
 
                    
                    try {           
                        Add-DnsServerResourceRecord -A -Name $dnsRecordToCreate -IPv4Address $randomIP -ZoneName $domainSuffix                                     
                        return $true
                    }
                    catch {
                        return $false
                    }
                }
  
                if ($result -eq $true) {
  
                    if ($showAllActions -eq $True) {
                        Write-Host "        + created dns record: $dnsRecordToCreate"
                    }
                }
                elseif ($result -eq $false) {
                    #not worth exiting
                    Write-Host "        - could not create dns record: $dnsRecordToCreate" -ForegroundColor Red
                }
            }
            elseif ($dnsRecordCheck -eq $true) {
                if ($showAllActions -eq $True) {
                    Write-Host "        - dns record already exists: $dnsRecordToCreate"                
                }
            }
        }   
        #dnsRecord delete
        dnsRecordDelete {
            $dnsRecordTypes = @("server", "workstation", "generic")
            $dnsRecordType = $dnsRecordTypes | Get-Random
  
            $dnsGenericRecords = @("email", "mail", "www", "vpn", "intranet", "sspr", "sharepoint", "hcm", "helpdesk")            
  
            switch ($dnsRecordType) {
                generic {
                    $dnsRecordToDelete = $dnsGenericRecords | Get-Random
                }
                server {
                    $computerToCheck = $null
                    $computerToCheck = Get-ADComputer -Filter * -SearchBase $ouServers
                        
                    if ($null -ne $computerToCheck) {
                        if ($computerToCheck.count -gt 1) { 
                            $computerToCheck = $computerToCheck | Get-Random
                        }   
                    }
  
                    $dnsRecordToDelete = $computerToCheck.Name
                }
                workstation { 
                    $computerToCheck = $null
                    $computerToCheck = Get-ADComputer -Filter * -SearchBase $ouWorkstations
                        
                    if ($null -ne $computerToCheck) {
                        if ($computerToCheck.count -gt 1) { 
                            $computerToCheck = $computerToCheck | Get-Random
                        }   
                    }
  
                    $dnsRecordToDelete = $computerToCheck.Name
                }       
            }
            
            $dnsRecordCheck = $null
            
            try {    
                $dnsRecordCheck = Get-DnsServerResourceRecord -Name $dnsRecordToDelete -ZoneName $domainSuffix -WarningAction SilentlyContinue -ErrorAction SilentlyContinue                  
            }
            catch {
                $dnsRecordCheck = $null
            }
                        
            if ($null -ne $dnsRecordCheck) {
                $result = Invoke-Command -ComputerName $dcName -ErrorAction Stop -ArgumentList $dnsRecordToDelete, $domainSuffix -Credential $domainAdminCredential -ScriptBlock {
                    
                    $dnsRecordToDelete = $args[0]
                    $domainSuffix = $args[1]                                        
                    
                    try {                        
                        Remove-DnsServerResourceRecord -Name $dnsRecordToDelete -RRType A -ZoneName $domainSuffix -Confirm:$false -Force
                        return $true
                    }
                    catch {
                        return $false
                    }
                }
  
                if ($result -eq $true) {
                    if ($showAllActions -eq $true) {
                        Write-Host "  + deleted dns record: $dnsRecordToDelete"
                    }
                }
                elseif ($result -eq $false) {                    
                    Write-Host "      - could not delete dns record: $dnsRecordToDelete" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      - dns record already deleted: $dnsRecordToDelete" -ForegroundColor Red
            }
        }               
        #gpo link
        gpoLink {
            $ouServers = "OU=servers,$domainBaseLocation"      
  
            $gpoAll = Get-GPO -All
  
            $gposToLink = @("Servers - ALL - Windows Update", "Servers - ALL - Temporary", "Servers - ALL - Legacy", "Servers - ALL - Blank")
            $gpoToLink = $gposToLink | Get-Random
  
  
            $gpoServer = $gpoAll | Where-Object { ($_.DisplayName -like "$gpoToLink") } 
  
            $gpoServerNL = $gpoServer | Where-Object {
                $_ | Get-GPOReport -ReportType XML | Select-String -NotMatch "<LinksTo>"
            }
  
            
            if ($null -ne $gpoServerNL) {
            
                $gpoServerNL = ($gpoServerNL | Get-Random).DisplayName
  
                $result = @()
                
                $result = Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $domainAdminCredential -ArgumentList $ouServers, $gpoServerNL -ScriptBlock {
                    $ouServers = $args[0]
                    $gpoServerNL = $args[1]
  
                    try {
                        New-GPLink -Name $gpoServerNL -Target $ouServers -LinkEnabled Yes -Enforced No | Out-Null
                        Return $True
                    }
                    catch {
                        Return $False
                    }
                }
                
                if ($result -eq $True) {
                    if ($showAllActions -eq $True) {
                        Write-Host "      + linked gpo: $gpoServerNL to $ouServers"
                    }
                }
                elseif ($result -eq $False) {
                    Write-Host "      - could not link gpo: $gpoServerNL to $ouServers" -ForegroundColor Red
                }
            }
            
        }         
        #gponew
        gpoNew {            
            $gposToCreate = @("Servers - ALL - Windows Update", "Servers - ALL - Temporary", "Servers - ALL - Legacy", "Servers - ALL - Blank")
            
            $gpoNAme = $gposToCreate
  
            foreach ($gpoName in $gposToCreate) {
            
                $gpoCheck = $null
  
                try {
                    $gpoCheck = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
                }
                catch {
                    $gpoCheck = $null
                }
              
                if ($null -eq $gpoCheck) {    
                    $result = $null
                    $result = Invoke-Command -ComputerName $dcName -ErrorAction Stop -ArgumentList $gpoName -Credential $domainAdminCredential -ScriptBlock {
                        try {
                            $gpoName = $args[0]
                            New-GPO -Name $gpoName -Comment $gpoName | Out-Null       
                            Return $True
                        }
                        catch {
                            Return $False
                        }         
                            
                        if ($result -eq $True) {
                            if ($showAllActions -eq $True) {
                                Write-Host "      + created gpo: $gpoName (or already exists)"  
                            }
                        }
                        elseif ($result -eq $False) {
                            Write-Host "      - could not create gpo: $gpoName" -ForegroundColor Red
                        }                                         
                    }                            
                }   
                else {
                    Write-Host "      + created gpo: $gpoName (already exists)" 
                } 
            }
        }    
        #gpo link remove
        gpoLinkRemove {
            $gposLinked = $null
            $gposLinked = (Get-GPInheritance -Target $ouServers).GpoLinks | Where-Object { $_.DisplayName -like "Servers - ALL - Temporary" }            
  
            if ($null -ne $gposLinked) {
                if ($gposLinked.Count -gt 1) {
                    $gpoServerLinked = ($gposLinked | Get-Random).DisplayName
                }
                else {
                    $gpoServerLinked = ($gposLinked | Get-Random).DisplayName
                }
                              
                $result = $null
                $result = Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $domainAdminCredential -ArgumentList $ouServers, $gpoServerLinked -ScriptBlock {
                    $ouServers = $args[0]
                    $gpoServerLinked = $args[1]
  
                    try {
                        Remove-GPLink -Name $gpoServerLinked -Target $ouServers | Out-Null
                        Return $True
                    }                        
                    catch {
                        Return $False
                    }
                }
                if ($result -eq $True) {
                    if ($showAllActions -eq $true) {
                        Write-Host "      + removed gpo link: $gpoServerLinked on $ouServers"
                    }
                }
                elseif ($result -eq $False) {                
                    Write-Host "      - could not remove gpo link: $gpoServerLinked on $ouServers" -ForegroundColor Red
                }                
            }
        }                                  
        #newSubnet{        
        newSubnet {
            try {
                $randomIP = "{0}.{1}.{2}.{3}" -f (Get-Random -Minimum 1 -Maximum 254),
                (Get-Random -Minimum 0 -Maximum 255),
                (Get-Random -Minimum 0 -Maximum 255),
                (Get-Random -Minimum 1 -Maximum 254)
                $randomIpNetmask = $randomIP -replace "\d{1,3}$", "0/24"
                $randomIpNetmaskLocation = "Subnet: $randomIpNetmask"
                Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $domainAdminCredential -ArgumentList $randomIpNetmask, $randomIpNetmaskLocation -ScriptBlock {
                    param($subnet, $location)
                    New-ADReplicationSubnet -Name $subnet -Location $location
                }
                if ($showAllActions -eq $true) {
                    Write-Host "      + created subnet: $randomIPNetMask"
                }
            }
            catch {
                Write-Host "      - could not create subnet: $randomIPNetMask" -ForegroundColor Red
            }
        }
        #setSPN for computer server
        setServerSPN {
            $computerToAction = $null          
            $computerToAction = Get-ADComputer -Filter * -Properties Description -SearchBase $ouServers
  
            $servicePrincipalName = $null    
            $servicePrincipalName = $servicePrincipalNames | Get-Random
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random
                }   
                try {
                    $dnsHostName = if ($computerToAction.DNSHostName) { $computerToAction.DNSHostName } else { "$($computerToAction.Name).$domainSuffix" }
                    $servicePrincipalName = $servicePrincipalName + '/' + $dnsHostName
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $domainAdminCredential -ArgumentList $computerToAction.DistinguishedName, $servicePrincipalName -ScriptBlock {
                        param($dn, $spn)
                        Set-ADComputer -Identity $dn -ServicePrincipalNames @{Add = $spn}
                    }
                    
                    Write-Host "      + set SPN: $servicePrincipalName on $($computerToAction.Name)"                    
                }
                catch {
                    Write-Host "      - could not set SPN: $servicePrincipalName on $($computerToAction.Name)" -ForegroundColor Red
                }
            }
        }
        #gpo registry value - modifies a benign registry-based policy setting in a designated lab GPO
        gpoRegistryValue {
            $gpoSafeTargets = @("Servers - ALL - Blank", "Servers - ALL - Temporary")

            # Harmless, cosmetic/UI-only registry settings - no security or stability impact
            $safeRegistrySettings = @(
                @{
                    Key    = "HKLM\Software\Policies\Microsoft\Windows NT\Reliability"
                    Name   = "ShutdownReasonUI"
                    Type   = "DWord"
                    Values = @(0, 1)
                },
                @{
                    Key    = "HKLM\Software\Policies\Microsoft\Windows\Explorer"
                    Name   = "ShowRunAsDifferentUserInStart"
                    Type   = "DWord"
                    Values = @(0, 1)
                },
                @{
                    Key    = "HKLM\Software\Policies\Microsoft\Windows\System"
                    Name   = "DisplayLastLogonInfo"
                    Type   = "DWord"
                    Values = @(0, 1)
                },
                @{
                    Key    = "HKLM\Software\Policies\Microsoft\Windows\CredUI"
                    Name   = "EnumerateAdministrators"
                    Type   = "DWord"
                    Values = @(0, 1)
                }
            )

            $gpoTarget = $null
            foreach ($gpoName in ($gpoSafeTargets | Sort-Object { Get-Random })) {
                try {
                    $gpoCheck = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
                    if ($null -ne $gpoCheck) {
                        $gpoTarget = $gpoCheck
                        break
                    }
                }
                catch { }
            }

            if ($null -ne $gpoTarget) {
                $setting = $safeRegistrySettings | Get-Random
                $value = $setting.Values | Get-Random

                $result = $null
                $result = Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $domainAdminCredential `
                    -ArgumentList $gpoTarget.DisplayName, $setting.Key, $setting.Name, $setting.Type, $value -ScriptBlock {
                        param($gpoName, $regKey, $regName, $regType, $regValue)
                        try {
                            Set-GPRegistryValue -Name $gpoName -Key $regKey -ValueName $regName -Type $regType -Value $regValue | Out-Null
                            return $true
                        }
                        catch {
                            return $false
                        }
                    }

                if ($result -eq $true) {
                    if ($showAllActions -eq $true) {
                        Write-Host "      + modified gpo registry value: $($gpoTarget.DisplayName) [$($setting.Name) = $value]"
                    }
                }
                elseif ($result -eq $false) {
                    Write-Host "      - could not modify gpo registry value: $($gpoTarget.DisplayName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no target GPO found for registry modification" -ForegroundColor Yellow
            }
        }
    }
}

Function Invoke-HelpdeskAction {
    param(
        [string]$helpdeskAction
    )
  
    $accountHelpdesk = ($actionAccounts | Where-Object { $_.ID -eq "helpdesk" }).AccountName
    $helpdeskCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountHelpdesk, $passwordSecure
  
    switch ($helpdeskAction) {
        #disable a user
        userDisable {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) {
                    $userToAction = $userToAction | Get-Random
                }
                                
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADUser -Identity $dn -Enabled $False
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + disabled user: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not disable user: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }
        #enable a user
        userEnable {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $False } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) {
                    $userToAction = $userToAction | Get-Random
                }
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADUser -Identity $dn -Enabled $True
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + enabled user: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not enable user: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no disabled users found" -ForegroundColor Yellow
            }
        }
        #disable computer
        computerDisable {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $True } -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADComputer -Identity $dn -Enabled $False
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + disabled computer: $($computerToAction.Name)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not disable computer: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        #enable a computer
        computerEnable {       
            $computerToAction = $null    
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $False } -SearchBase $ouWorkstations
  
            if ($null -ne $computerToAction) {                
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADComputer -Identity $dn -Enabled $True
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + enabled computer: $($computerToAction.Name)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not enable computer: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        #abnormal password reset with 30 second delay
        passwordAbnormalRefresh {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
  
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }                
                
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADUser -Identity $dn -ChangePasswordAtLogon $True
                        Start-Sleep -Seconds 10
                        Set-ADUser -Identity $dn -ChangePasswordAtLogon $False
                    }
                    Write-Host "      + abnormaly refreshed password: $($userToAction.SamAccountName)"
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not abnormaly refresh password: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }        
        #set password at next logon
        passwordAtNextLogon {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
  
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }                
                
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADUser -Identity $dn -ChangePasswordAtLogon $True
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + change password at next logon set: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not set change password at next logon: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }
        #reset password
        passwordReset {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            $userPassword = New-ComplexPassword -passwordLength 14
  
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }              
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName, $userPassword -ScriptBlock {
                        param($dn, $pwd)
                        Set-ADAccountPassword -Identity $dn -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $pwd -Force)
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + changed password: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not change password: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }     
        #reset password
        passwordResetInDescription {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            $userPassword = New-ComplexPassword -passwordLength 14
  
            if ($null -ne $userToAction) {                
  
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }              
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName, $userPassword -ScriptBlock {
                        param($dn, $pwd)
                        Set-ADAccountPassword -Identity $dn -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $pwd -Force)
                        Set-ADUser -Identity $dn -Description "Password: $pwd"
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + changed password and updated user description: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not set password in description: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }   
        updateConfidentialGroup {
            #select a random department and add the user to that
            $pamGroup = ($confidentialGroups | Get-Random).Name           
  
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees
            
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
            } 
            
            try {
                Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $pamGroup, $userToAction.DistinguishedName -ScriptBlock {
                    param($group, $userDN)
                    Add-ADGroupMember -Identity $group -Members $userDN
                }
                Write-Host "    + added user: $($userToAction.SamAccountName) to $pamGroup"
            }
            catch {
                #not worth exiting
                Write-Host "    - could not add user: $($userToAction.SamAccountName) to $pamGroup" -ForegroundColor Red
            }
        }   
        #update description
        userUpdateDescription {
            $userToAction = $null          
            $userToAction = Get-ADUser -Filter { Description -like "*" } -Properties Description -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
                try {
                    $userToActionDescription = $userToAction.Description + ' I'
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $helpdeskCredential -ArgumentList $userToAction.DistinguishedName, $userToActionDescription -ScriptBlock {
                        param($dn, $desc)
                        Set-ADUser -Identity $dn -Description $desc
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + changed description: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not change description: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }        
    }
}
  
Function Invoke-ServerAction {
    param(
        [string]$serverAction
    )
  
    $accountServer = ($actionAccounts | Where-Object { $_.ID -eq "server" }).AccountName
    $serverCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountServer, $passwordSecure
  
    switch ($serverAction) {
        #delete computer/server
        computerDelete {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter * -SearchBase $ouServers
            
            if ($null -ne $computerToAction) {
  
                if ($computerToAction.Count -gt 1) {
                    $computerToAction = $computerToAction[(Get-Random -Minimum 0 -Maximum $computerToAction.Count)]
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Remove-ADComputer -Identity $dn -Confirm:$False
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + server deleted: $($computerToAction.Name)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not delete server: $($computerToAction.Name)" -ForegroundColor Red
                }
            } 
            else {
                Write-Host "      ~ no servers found" -ForegroundColor Yellow
            }
        }
        #disable computer
        computerDisable {        
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $True } -SearchBase $ouServers
            
            if ($null -ne $computerToAction) {
  
                if ($computerToAction.Count -gt 1) {
                    $computerToAction = $computerToAction[(Get-Random -Minimum 0 -Maximum $computerToAction.Count)]
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADComputer -Identity $dn -Enabled $False
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + server disabled: $($computerToAction.Name)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "      - could not disable server: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no servers found" -ForegroundColor Yellow
            }      
        }
        #enable computer
        computerEnable {        
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $False } -SearchBase $ouServers
            
            if ($null -ne $computerToAction) {
  
                if ($computerToAction.Count -gt 1) {
                    $computerToAction = $computerToAction[(Get-Random -Minimum 0 -Maximum $computerToAction.Count)]
                }
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $computerToAction.DistinguishedName -ScriptBlock {
                        param($dn)
                        Set-ADComputer -Identity $dn -Enabled $True
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "      + server enabled: $($computerToAction.Name)"
                    }
                }
                catch {
                    Write-Host "      - could not enable: $($computerToAction.Name)" -ForegroundColor Red
                }
            } 
            else {
                Write-Host "      ~ no disabled servers found" -ForegroundColor Yellow
            }                 
        }        
        #create a new server, based on enterprise apps
        computerNew {        
            $enterpriseApp = $selectedEnterpriseApps | Get-Random
  
            $appEnv = $enterpriseAppsEnvironments | Get-Random
            $appName = $enterpriseApp.Name
            $appCode = $enterpriseApp.Id
            $ouAppPath = "OU=$appName,$ouServers"
            
            # Check if OU exists, create if not
            try {
                Get-ADOrganizationalUnit -Identity $ouAppPath -ErrorAction Stop | Out-Null
            }
            catch {
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $appName, $ouServers -ScriptBlock {
                        param($name, $path)
                        New-ADOrganizationalUnit -Name $name -Path $path
                    }
                }
                catch {
                    # OU may already exist or other error
                }
            }

            $serverGroup = "$appName-$appEnv-Servers"
  
            if ($appCode -eq "LNX") {
                $osVersion = Get-Random -InputObject $osVersionsLinux
            }
            else {
                $osVersion = Get-Random -InputObject $osVersionsWindows
            }
  
            $i = 1
            $match = $true
  
            while ($match) {
                $suffix = "{0:D3}" -f $i
                $computerName = "$appCode$appEnv$suffix"

                $existing = Get-ADComputer -Filter "Name -eq '$computerName'" -ErrorAction SilentlyContinue
                if ($null -ne $existing) {
                    $i++
                }
                else {
                    $match = $false
                }
            }
  
            $computerDNS = "$computerName.$domainSuffix"
            
            try {
                Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $computerName, $computerDNS, $ouAppPath, $osVersion, "$appName $appEnvserver" -ScriptBlock {
                    param($name, $dns, $path, $os, $desc)
                    New-ADComputer -Name $name -SAMAccountName $name -DNSHostName $dns -Path $path -OperatingSystem $os -Description $desc
                }
                $serverGroup = "$appName-$appEnv-Servers"
                Start-Sleep -Milliseconds 500
                Write-Host "          + created server: $computerName"
            }
            catch {
                Write-Host "          - server could not be created: $computerName" -ForegroundColor Red
                if ($continueOnError -eq $false) {
                    Write-Host "          - continue on error set to false, exiting" -ForegroundColor Red
                    Exit
                }
            }
			
			try {
				Get-ADGroup -Identity $serverGroup -ErrorAction Stop | Out-Null
			}
			catch {
				try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $serverGroup, $ouGroups -ScriptBlock {
                        param($groupName, $path)
                        New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $path
                    }
				}
				catch {
					# Group may already exist or other error
				}
			}
			
            try {
                Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $serverGroup, $computerName -ScriptBlock {
                    param($group, $name)
                    Add-ADGroupMember -Identity $group -Members "$name$"
                }
            }
            catch {
                Write-Host "            - server could not be added to server group" -ForegroundColor Red
            }
        }
        #add a member to a group
        groupNewMember {        
            $groupToUpdate = Get-ADGroup -Filter { Name -like "*-Servers" } -SearchBase $ouGroups
  
  
            if ($null -ne $groupToUpdate) {
                
                $groupToUpdate = $GroupToUpdate | Get-Random 
  
                $serverToAction = $null
                $serverToAction = Get-ADComputer -Filter * -SearchBase $ouServers
  
                if ($null -ne $serverToAction) {
                    if ($serverToAction.Count -gt 1) {
                        $serverToAction = $serverToAction | Get-Random
                    }
                
                    try {
                        Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serverCredential -ArgumentList $groupToUpdate.DistinguishedName, $serverToAction.DistinguishedName -ScriptBlock {
                            param($groupDN, $serverDN)
                            Add-ADGroupMember -Identity $groupDN -Members $serverDN
                        }
                        if ($showAllActions -eq $True) {
                            Write-Host "      + added server: $($serverToAction.Name) to $($groupToUpdate.Name)"
                        }
                    }
                    catch {
                        #not worth exiting
                        Write-Host "      - could not add:  $($serverToAction.Name) to $($groupToUpdate.Name)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "      ~ no servers found" -ForegroundColor Yellow
                }                            
            }
            else {
                Write-Host "      ~ no groups found" -ForegroundColor Yellow
            }  
        }
    }
}
  
Function Invoke-ServiceAccountAction {  
    param(
        [string]$serviceAccount 
    )
   
    $serviceAccountCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $serviceAccount, $passwordSecure
  
    switch ($serviceAccount) {
        #updates the iphone field for users
        svc-callmanager {            
            $userToAction = $null
            $userToAction = Get-ADUser -Filter * -SearchBase $ouEmployees
            
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
  
                $userIPPhone = "+" + (Get-Random -Minimum 123456789012 -Maximum 923456789012).ToString('00000')
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serviceAccountCredential -ArgumentList $userToAction.DistinguishedName, $userIPPhone -ScriptBlock {
                        param($userDN, $phone)
                        Set-ADUser -Identity $userDN -Replace @{ipPhone = $phone}
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "    + svc-callmanager updated: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "    - svc-callmanager could not update: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "    - no valid accounts found, skipping" -ForegroundColor Yellow
            }         
    
           
        }                     
        #disables and account
        svc-offboarding {
            $userToAction = $null
            
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees 
           
            if ($null -eq $userToAction) {
                Write-Host "    - no enabled accounts found, skipping" -ForegroundColor Yellow
            } 
            elseif ($null -ne $userToAction) {
  
                $userToAction = $userToAction | Get-Random
  
                try {
                    Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serviceAccountCredential -ArgumentList $userToAction.DistinguishedName, $ouEmployeesExpired -ScriptBlock {
                        param($userDN, $targetPath)
                        Set-ADUser -Identity $userDN -Enabled $False
                        Move-ADObject -Identity $userDN -TargetPath $targetPath
                    }
                    if ($showAllActions -eq $True) {
                        Write-Host "    + svc-offboarding disabled: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    #not worth exiting
                    Write-Host "    - svc-offboarding could not disable: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
        }
        #create an account
        svc-onboarding {
            $userToAction = $null
            $userToAction = New-RealADUser -Credential $serviceAccountCredential           
        }
        svc-pam {
            #select a random department and add the user to that
            $pamGroup = ($confidentialGroups | Get-Random).Name           
  
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees
            
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
            } 
            
            try {
                Invoke-Command -ComputerName $dcName -ErrorAction Stop -Credential $serviceAccountCredential -ArgumentList $pamGroup, $userToAction.DistinguishedName -ScriptBlock {
                    param($group, $userDN)
                    Add-ADGroupMember -Identity $group -Members $userDN
                }
                Write-Host "    + svc-pam added user: $($userToAction.SamAccountName) to $pamGroup"
            }
            catch {
                #not worth exiting
                Write-Host "    - svc-pam could not add user: $($userToAction.SamAccountName) to $pamGroup" -ForegroundColor Red
            }
        }          
    }
}
  
Function New-ComplexPassword {
    Param(
        [parameter(Mandatory = $true)][ValidateRange(0, [int]::MaxValue)][Int]$passwordLength
    ) 
  
    #password length - 4 (to ensure 1 type of each character)
    #if no password length specified assume 12 characters
    if ($passwordLength -lt 14) {
        #Write-Warning "Password length too short, defaulting to 12 characters"
        $passwordLength = 14
    }
  
    $passwordLength = $passwordLength - 4
    
    #get a lowercase character
    $charsLower = 97..122 | ForEach-object { [Char] $_ }     
    $cLower = $charsLower[(Get-Random $charsLower.count)]
  
    #get an uppercase character
    $charsUpper = 65..90 | ForEach-object { [Char] $_ } 
    $cUpper = $charsUpper[(Get-Random $charsUpper.count)]
  
    #get a number
    $charsNumber = 48..57 | ForEach-object { [Char] $_ } 
    $cNumber = $charsNumber[(Get-Random $charsNumber.count)]
  
    #get a symbol
    #full list of symbols, some of them Exit password
    #$charsSymbol = 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 58, 59, 60, 61, 62, 63, 64, 91, 92, 93, 94, 95, 96, 123, 124, 125,126 | ForEach-object { [Char] $_ } 
    $charsSymbol = 35, 36, 40, 41, 42, 44, 45, 46, 47, 58, 59, 63, 64, 92, 95 | ForEach-object { [Char] $_ } 
    $cSymbol = $charsSymbol[(Get-Random $charsSymbol.count)]
    
    #complete the rest of the password
    $ascii = $NULL;
    for ($a = 48; $a -le 122; $a++) {
        $ascii += , [char][byte]$a
    }
   
    for ($loop = 1; $loop -le $passwordLength; $loop++) {
        $thePassword += ($ascii | GET-RANDOM)
    }
  
    #compile the password and return it
    $thePassword += $cLower + $cUpper + $cNumber + $cSymbol 
  
    #randomize the string, so it doesn't always end with lower, upper, number, symbol
    $thePassword = ($thePassword -split '' | Sort-Object { Get-Random }) -join ''
   
    $thePassword
}
  
Function New-RealADUser {
    param(        
        [System.Management.Automation.PSCredential]$Credential,
        [bool]$allowDES,
        [bool]$allowReversionEncryption,
        [bool]$passNotRequired
    )
  
    if ($null -ne $usersToCreate) {
        #use random values to create multi thousand unique options!
  
        $userToCreateBase = ($usersToCreate | Get-Random)
  
        $uFirstName = Remove-StringLatinCharacters -String $userToCreateBase.name.first
        $uLastName = Remove-StringLatinCharacters -String ($usersToCreate | Get-Random).Name.last
  
        $ulocation = $userToCreateBase.location
        $uStreet = Remove-StringLatinCharacters -String $ulocation.street.name
        $uStreet = $ulocation.street.number.ToString() + ' ' + $uStreet
                      
        $uPasswordClear = New-ComplexPassword -passwordLength 14
        $uPasswordEncrypted = ConvertTo-SecureString -AsPlainText $uPasswordClear -Force
  
        do {
            $uEmployeeID = Get-Random -Minimum 500 -Maximum 500000
            
            if ($uEmployeeID.Length -lt 6) {
                $uEmployeeID = $uEmployeeID.ToString().PadLeft(6, "0")
                $SamAccountName = "E$uEmployeeID"          
            }    
        } while (Get-ADUser -Filter { SamAccountName -eq $SamAccountName })
  
        $uUpnBase = "$uFirstName.$uLastName@$domainSuffix"
        $uUpn = $uUpnBase
        $counter = 1
        $duplicate = $false
  
        do {
            $existingUser = Get-ADUser -Filter { UserPrincipalName -eq $uUpn }
  
            if ($existingUser) {
                #found duplicate
                $duplicate = $true
                $uUpn = "$uFirstName.$uLastName$counter@$domainSuffix"
                $counter++
            }
        } while ($existingUser)
   
        #department and job role
        $uDepartment = Get-Random -InputObject ($selectedDepartments | Where-Object { $_.Name -ne "C-Suite" })
        $uDepartmentName = $uDepartment.Name
        $uDepartmentPosition = Get-Random -InputObject $uDepartment.Positions
        $uDepartmentLevel = Get-Random -InputObject $departmentsJobLevels
        $uJobTitle = "$uDepartmentPosition $uDepartmentLevel"
        $deptRoleGroupName = "$uDepartmentName - $uDepartmentPosition"              
        
        $userParameters = $null
        $userParameters = @{
            SamAccountName        = $SamAccountName
            EmployeeID            = $uEmployeeID
            GivenName             = $uFirstName
            Surname               = $uLastName
            City                  = $ulocation.City
            EmailAddress          = $uUpn
            EmployeeNumber        = $uEmployeeID
            UserPrincipalName     = $uUpn
            Enabled               = $True
            ChangePasswordAtLogon = $False
            Department            = $uDepartmentName
            Description           = $uJobTitle
            Title                 = $uJobTitle
            Country               = $userToCreateBase.nat
            StreetAddress         = $uStreet
            PostalCode            = $ulocation.postcode
            Company               = $domainSuffix
            AccountPassword       = $uPasswordEncrypted
            Path                  = $ouEmployees
            Credential            = $Credential
        }
  
        if ($duplicate -eq $true) {
            #subtract 1 because counter
            $userParameters["Name"] = "$uLastName($($counter-1)), $uFirstName"
            $userParameters["DisplayName"] = "$uLastName($($counter-1)), $uFirstName"
        }
        else {
            $userParameters["Name"] = "$uLastName, $uFirstName"
            $userParameters["DisplayName"] = "$uLastName, $uFirstName"
        }
        
        #only if set
        if ($allowReversionEncryption) { $userParameters["AllowReversiblePasswordEncryption"] = $true }
        if ($passNotRequired) { $userParameters["PasswordNotRequired"] = $true }
  
        #convert hashtable to PSCustomObject
        $userObject = [PSCustomObject]$userParameters
  
        try {            
            if ($Credential -and $Credential.UserName) {
                $userObject | New-ADUser  -Credential $Credential
            }
            else {
                $userObject | New-ADUser   
            }
  
            Start-Sleep -Milliseconds 100
  
            #if ($showAllActions -eq $True) {
                Write-Host "    + created user account: $SamAccountName"                     
            #}
        }
        catch {
            Write-Host "    - could not create user: $SamAccountName" -ForegroundColor Red
  
            if ($continueOnError -eq $false) {
                Write-Host "  - continue on error set to false, exiting" -ForegroundColor Red                    
                Exit
            }            
        }             
        
        #add to department group
        try {
            if ($Credential -and $Credential.UserName) {
                Add-ADGroupMember -Identity $deptRoleGroupName -Members $SamAccountName  -Credential $Credential      
                
            }
            else {
                Add-ADGroupMember -Identity $deptRoleGroupName -Members $SamAccountName 
               
            }
  
            if ($showAllActions -eq $True) {
                Write-Host "      + user added to department role group: $deptRoleGroupName"
            }
        }
        catch {
            Write-Host "      - could not add user to department role group: $deptRoleGroupName" -ForegroundColor Red
  
            if ($continueOnError -eq $false) {
                Write-Host "  - continue on error set to false, exiting" -ForegroundColor Red                    
                Exit
            }  
        }
  
        if ($allowDES) {                         
            $newUser = Get-ADUser -Identity $SamAccountName -Properties UserAccountControl
            $CurrentUAC = $newUser.UserAccountControl
  
            #enforce des
            $NewUAC = $CurrentUAC -bor 0x200000
            
            if ($Credential -and $Credential.UserName) {
                Set-ADUser -Identity $newUser -Replace @{UserAccountControl = $NewUAC } -Credential $Credential
            }
            else {
                Set-ADUser -Identity $newUser -Replace @{UserAccountControl = $NewUAC }
            }
        }
  
        #set proxy addresses
        try {
            #define primary and secondary SMTP addresses
            $primarySMTP = "SMTP:$uUpn"
            $secondarySMTP = "smtp:$SamAccountName@$domainSuffix"
  
            $smtpProxies = @($primarySMTP, $secondarySMTP)
          
            if ($Credential -and $Credential.UserName) {
                Set-ADUser -Identity $SamAccountName -Replace @{proxyAddresses = $smtpProxies } -Credential $Credential
            }
            else {
                Set-ADUser -Identity $SamAccountName -Replace @{proxyAddresses = $smtpProxies } 
            }
        }
        catch {
            Write-Host "      - could not set proxy address: $SamAccountName" -ForegroundColor Red
        }
 
    }
    else {
        Write-Host "      - no user object data, exiting" -ForegroundColor Red
        Exit
    }
}
  
Function New-Workstation {
    $computerType = @("ENG", "FLD", "KSK", "WKS", "VDI")
    $computerType = $computerType | Get-Random
  
    $ouWorkstationTarget = $null
  
    switch ($computerType) {
        ENG {
            $ouWorkstationTarget = "OU=Engineering,$ouWorkstations"
        }
        FLD {
            $ouWorkstationTarget = "OU=Field,$ouWorkstations"
        }
        KSK {
            $ouWorkstationTarget = "OU=Kiosks,$ouWorkstations"
        }
        WKS {
            $ouWorkstationTarget = $ouWorkstations
        }
        VDI {
            $ouWorkstationTarget = "OU=VDI,$ouWorkstations"
        }
    }
  
    $computerString = -join ((65..90) | Get-Random -Count 9 | ForEach-Object { [char]$_ })
    $computerStringNumber = (1..99).ForEach({ '{0:D2}' -f $_ })[(Get-Random -Minimum 0 -Maximum 99)]
            
    $computerName = "$computerType-$computerString$computerStringNumber"
    $computerDNS = "$computerName.$domainSuffix"
  
    #all will be this very, because lazy and not real anyway
    $computerOS = "Windows 11 Pro"
    $computerOSVersion = "10.0 (22621)"
  
    try {
        New-ADComputer -Name $computerName -DNSHostName $computerDNS -Description $computerDNS -OperatingSystem $computerOS -OperatingSystemVersion $computerOSVersion -Enabled $true -Path $ouWorkstationTarget #-Credential $desktopCredential 
                
        if ($showAllActions -eq $True) {
            Write-Host "    + created computer: $computerName"  
        }
    }
    catch {
        Write-Host "    - could not create computer: $computerName" -ForegroundColor Red
  
        if ($continueOnError -eq $false) {
            Write-Host "   - continue on error set to false, exiting" -ForegroundColor Red                    
            Exit
        }  
    }
}
  
Function Remove-StringLatinCharacters {
    #used by the new-realaduser functiom, if there are any weird cyrillic characters returned
    param (
        [string]$String
    )
  
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}
  
#action weighting, each role is giving a score which is the wait i.e. how likely it is to do something compared to the other accounts
#each role has a list of actions, which then is scored the same, how likely it is that the chosen role does this action
  
#roles weightning i.e. helpdesk 5 times likelier than domain admin
$rolesList = @{}
$rolesList.Add('helpdesk',5)
$rolesList.Add('service',4)
$rolesList.Add('desktop',3)
$rolesList.Add('server',2)
$rolesList.Add('domainadmin',1)
  
  
#helpdesk admin actions
$helpdeskActions = @{}
$helpdeskActions.Add('passwordReset','5')
$helpdeskActions.Add('passwordResetInDescription','1')
$helpdeskActions.Add('userEnable','1')
$helpdeskActions.Add('userDisable','3')
$helpdeskActions.Add('computerEnable','2')
$helpdeskActions.Add('computerDisable','3')
$helpdeskActions.Add('passwordAbnormalRefresh','1')
$helpdeskActions.Add('passwordAtNextLogon','2')
$helpdeskActions.Add('updateConfidentialGroup','1')
  
  
#desktop admin actions
$desktopActions = @{}
$desktopActions.Add('computerNew','5')
$desktopActions.Add('updateDepartmentGroup','4')
$desktopActions.Add('computerDisable','3')
$desktopActions.Add('computerEnable','3')
$desktopActions.Add('computerDelete','1')
$desktopActions.Add('userDisable','2')
$desktopActions.Add('userNew','1')
$desktopActions.Add('userNewDesEncryption','1')
$desktopActions.Add('userNewReversibleEncryption','1')
$desktopActions.Add('userNewPasswordNotRequired','1')
  
  
#server actions
$serverActions = @{}
$serverActions.Add('computerNew','5')
$serverActions.Add('groupNewMember','4')
$serverActions.Add('computerEnable','3')
$serverActions.Add('computerDisable','3')
$serverActions.Add('computerDelete','1')
  
  
#service accounts
$serviceAccounts = @{}
$serviceAccounts.Add('svc-onboarding','4')
$serviceAccounts.Add('svc-callmanager','3')
$serviceAccounts.Add('svc-offboarding','2')
$serviceAccounts.Add('svc-pam','2')
  
  
#domain admin actions
$domainAdminActions = @{}
$domainAdminActions.Add('dnsRecordAdd','3')
$domainAdminActions.Add('dnsRecordDelete','2')
$domainAdminActions.Add('gpoLink','2')
$domainAdminActions.Add('gpoLinkRemove','2')
$domainAdminActions.Add('gpoNew','1')
$domainAdminActions.Add('newSubnet','1')
$domainAdminActions.Add('setServerSPN','1')
$domainAdminActions.Add('gpoRegistryValue','1')
  
  
#assign weights to roles and actions
$rolesListWeighted = @()
$rolesList.GetEnumerator() | ForEach-Object {   
    $weight = $_.value -as [int]
    
    for ($i = 1; $i -le $weight; $i++) {    
        $rolesListWeighted += $_.key
    }        
}
  
#desktop actions
$desktopActionsWeighted = @()
$desktopActions.GetEnumerator() | ForEach-Object {
    $weight = $_.value -as [int]
    
    for ($i = 1; $i -le $weight; $i++) {    
        $desktopActionsWeighted += $_.key
    }        
}
$desktopActionsWeighted = $desktopActionsWeighted | Sort-Object {Get-Random}
  
#domain admins
$domainAdminActionsWeighted = @()
$domainAdminActions.GetEnumerator() | ForEach-Object {  
    $weight = $_.value -as [int]
    
    for ($i = 1; $i -le $weight; $i++) {    
        $domainAdminActionsWeighted += $_.key
    }        
}
$desktopActionsWeighted = $desktopActionsWeighted | Sort-Object {Get-Random}
  
#helpdesk actions
$helpdeskActionsWeighted = @()
$helpdeskActions.GetEnumerator() | ForEach-Object {     
    $weight = $_.value -as [int]
    
    for ($i = 1; $i -le $weight; $i++) {    
        $helpdeskActionsWeighted += $_.key
    }        
}
$helpdeskActionsWeighted = $helpdeskActionsWeighted | Sort-Object {Get-Random}
  
  
#server actions weighted
$serverActionsWeighted = @()
$serverActions.GetEnumerator() | ForEach-Object {     
    $weight = $_.value -as [int]
    
    for ($i = 1; $i -le $weight; $i++) {    
        $serverActionsWeighted += $_.key
    }        
}
$serverActionsWeighted = $serverActionsWeighted | Sort-Object {Get-Random}
  
#service-accounts 
$serviceAccountsWeighted = @()
$serviceAccounts.GetEnumerator() | ForEach-Object {     
    $weight = $_.value -as [int]
    
    for ($i = 1; $i -le $weight; $i++) {    
        $serviceAccountsWeighted += $_.key
    }        
}
$serviceAccountsWeighted = $serviceAccountsWeighted | Sort-Object {Get-Random}
  
#start transript
if (-not $TestOnly) { Start-Transcript -Path $fLogFile | Out-Null }

try {
    $dcObj = Get-ADDomainController -Discover
    $dcName = [string]$dcObj.HostName[0]
    $domain = Get-ADDomain -Server $dcName
    $domainDN = $domain.DistinguishedName
    $domainSuffix = $domain.DNSRoot
}
catch {
    Write-Host " - could not contact domain" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
    if (-not $TestOnly) { Stop-Transcript }
    Exit
}

if ([string]::IsNullOrEmpty($domainDN)) {
    Write-Host " - domainDN is empty, cannot continue" -ForegroundColor Red
    if (-not $TestOnly) { Stop-Transcript }
    Exit
}

if (-not $TestOnly) {
    Write-Host "=============================================================="
    Write-Host "                   Automated Lab Changer                      "
    Write-Host "                        $logFileDate                          "
    Write-Host "=============================================================="
    Write-Host "+ domain:   $domainSuffix"
    Write-Host "+ password: $passwordDefault"
    Write-Host ""
    Write-Host "+ max actions: $actionsMax"
    Write-Host "+ action wait: $actionsWait"
    Write-Host ""
    Write-Host "+ user data file: $offlineUserData"
    Write-Host "--------------------------------------------------------------"
    Write-Host "=============================================================="
    Write-Host "+ logfile:  $fLogFile"
    Write-Host "=============================================================="
}
  
  
if ($offlineUserData -ne "") {
    try {
        if (Test-Path -Path $offlineUserData) {
            try {
                $usersToCreate = Get-Content -Path $offlineUserData -Raw | ConvertFrom-Json                
            } 
            catch {
                Write-Host "- failed to import offline data file, ensure the file contains valid JSON" -ForegroundColor Red
                if ($continueOnError -eq $false) {
                    Exit
                }                    
            }
        }
        else {
            Write-Host "- could not find offline data file, ensure the file exists." -ForegroundColor Red            
            if ($continueOnError -eq $false) {        
                Exit
            } 
            else{
                $offlineUserData = ""
            }
        }
    }
    catch {
        Write-Host "- offline data file not valid, ensure it exists and is a valid JSON file." -ForegroundColor Red
  
        if ($continueOnError -eq $false) {
            Exit
        }
        else{
            $offlineUserData = ""
        } 
    }
}
  
  
if ($offlineUserData -eq "") {
    #try get user accounts from randomuser.me api, this supports a maximum of 5000 objects, get 5000 objects then do some trickery by building names using a selection of random values
  
    Write-Host "+ no offline data file provided, attempting to download"
  
    try {
        $usersToCreate = Invoke-RestMethod -Uri "https://randomuser.me/api/?results=5000&inc=name,location,nat&nat=$userCountryCodes&dl" | Select-Object -ExpandProperty Results
        Write-Host "+ user data downloaded"
    }
    catch {
        Write-Host "- could not download user object data"
        Write-Host "- could not connect to https://randomuser.me api and no offline file provided, exiting" -ForegroundColor Red
        Exit
    }
}
  
  
#build the naming for the base OU
$domainBaseLocation = "OU=$domainBase,$domainDN"
$baseOUAdmin = "OU=Administrative,$domainBaseLocation"
  
  
  
  
$baseOUS = $null
$baseOUS = @(
    @{ID = 0; Name = "$domainBase"; Path = "$domainDN"; DN = "OU=$domainBase,$domainDN" },
  
    @{ID = 1; Name = "_New"; Path = "$domainBaseLocation"; DN = "OU=_New,$domainBaseLocation"; Code = "defNew" },
    @{ID = 2; Name = "Computer"; Path = "OU=_New,$domainBaseLocation"; DN = "OU=Computer,OU=_New,$domainBaseLocation"; Code = "defNewComputer" },
    @{ID = 3; Name = "User"; Path = "OU=_New,$domainBaseLocation"; DN = "OU=User,OU=_New,$domainBaseLocation"; Code = "defNewUser" },
  
    @{ID = 4; Name = "_Expired"; Path = "$domainBaseLocation"; DN = "OU=_Expired,$domainBaseLocation" },
    @{ID = 5; Name = "Employees"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Employees,OU=_Expired,$domainBaseLocation"; Code = "defEmployeesExpired" },
    @{ID = 6; Name = "Groups"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Groups,OU=_Expired,$domainBaseLocation"; Code = "defGroupsExpired" },
    @{ID = 7; Name = "Servers"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Servers,OU=_Expired,$domainBaseLocation"; Code = "defServersExpired" },
    @{ID = 8; Name = "Workstations"; Path = "OU=_Expired,$domainBaseLocation"; DN = "OU=Workstations,OU=_Expired,$domainBaseLocation"; Code = "defWorkstationsExpired" },
  
    @{ID = 9; Name = "Administrative"; Path = "$domainBaseLocation"; DN = "OU=Administrative,$domainBaseLocation"; Code = "defAdmin" },
    @{ID = 10; Name = "Confidential"; Path = "$domainBaseLocation"; DN = "OU=Confidential,$domainBaseLocation"; Code = "defConfidential" },
    @{ID = 11; Name = "Departments"; Path = "$domainBaseLocation"; DN = "OU=Departments,$domainBaseLocation"; Code = "defDepartments" },
    @{ID = 12; Name = "Employees"; Path = "$domainBaseLocation"; DN = "OU=Employees,$domainBaseLocation"; Code = "defEmployees" },
    @{ID = 13; Name = "VIPs"; Path = "OU=Employees,$domainBaseLocation"; DN = "OU=VIPs,OU=Employees,$domainBaseLocation"; Code = "defEmployeesVips" },
    @{ID = 14; Name = "Groups"; Path = "$domainBaseLocation"; DN = "OU=Groups,$domainBaseLocation"; Code = "defGroups" },
    @{ID = 15; Name = "Quarantined"; Path = "$domainBaseLocation"; DN = "OU=Quarantined,$domainBaseLocation" },
    @{ID = 16; Name = "Employees"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Employees,OU=Quarantined,$domainBaseLocation"; Code = "defEmployeesQuarantined" },
    @{ID = 17; Name = "Groups"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Groups,OU=Quarantined,$domainBaseLocation"; Code = "defGroupsQuarantined" },
    @{ID = 18; Name = "Servers"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Servers,OU=Quarantined,$domainBaseLocation"; Code = "defServersQuarantined" },
    @{ID = 19; Name = "Workstations"; Path = "OU=Quarantined,$domainBaseLocation"; DN = "OU=Workstations,OU=Quarantined,$domainBaseLocation"; Code = "defWorkstationsQuarantined" },
  
    @{ID = 20; Name = "Servers"; Path = "$domainBaseLocation"; DN = "OU=Servers,$domainBaseLocation"; Code = "defServers" },
    @{ID = 21; Name = "Workstations"; Path = "$domainBaseLocation"; DN = "OU=Workstations,$domainBaseLocation"; Code = "defWorkstations" }
    @{ID = 22; Name = "Engineering"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=Engineering,OU=Workstations,$domainBaseLocation"; Code = "defEngineeringWorkstations" },
    @{ID = 23; Name = "Field"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=Field,OU=Workstations,$domainBaseLocation"; Code = "defFieldWorkstations" }, 
    @{ID = 24; Name = "Kiosks"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=Kiosks,OU=Workstations,$domainBaseLocation"; Code = "defKiosksWorkstations" },
    @{ID = 25; Name = "VDI"; Path = "OU=Workstations,$domainBaseLocation"; DN = "OU=VDI,OU=Workstations,$domainBaseLocation"; Code = "defVDIWorkstations" }
)
  
$actionAccounts = @(
    @{ID = "domainadmin"; Tier = "Tier0"; TierGroup = "T0_Admins_Global_RG"; AccountName = "domain-admin" }
    @{ID = "rogue"; Tier = "Tier0"; TierGroup = "T0_Admins_Global_RG"; AccountName = "rogue-admin" }
    @{ID = "network"; Tier = "Tier1"; TierGroup = "T1_NetworkAdmin_Global_RG"; AccountName = "network-admin" }
    @{ID = "server"; Tier = "Tier1"; TierGroup = "T1_ServerAdmin_Global_RG"; AccountName = "server-admin" }
    @{ID = "desktop"; Tier = "Tier2"; TierGroup = "T2_DesktopSupport_Global_RG"; AccountName = "desktop-admin" }
    @{ID = "helpdesk"; Tier = "Tier2"; TierGroup = "T2_HelpDesk_RG"; AccountName = "helpdesk-admin" }
    @{ID = "cloud"; Tier = "TierCloud"; TierGroup = "TC_CloudAdmins_RG"; AccountName = "cloud-admin" }    
    @{ID = "vipadmin"; Tier = "Tier2"; TierGroup = "T2_VIP_Support_RG"; AccountName = "vip-admin" }        
)
  
  
#service accounts, also used for actions
$serviceAccounts = @(
    @{ID = "svc-callmanager"; Permission = "Account Operators"; SPN = "http/callmanager.$($domainSuffix)" }
    @{ID = "svc-onboarding"; Permission = "Account Operators"; SPN = "" }
    @{ID = "svc-offboarding"; Permission = "Account Operators"; SPN = "" }
    @{ID = "svc-pam"; Permission = "Account Operators"; SPN = "http/pam.$($domainSuffix)" }
 ) 
  
$departments = @(
    @{"Name" = "Accounting"; Positions = @("Accounting Manager", "Accounts Clerk", "Data Entry", "Cost Accountant", "Management Accountant") },
    @{"Name" = "Administration"; Positions = @("Administration Manager", "Administrator", "Administration Assistant", "Administration Coordinator") },
    @{"Name" = "Business Development"; Positions = @("Business Development Manager", "Business Development Strategist", "Business Development Consultant") },
    @{"Name" = "Cloud Services"; Positions = @("Cloud Services Manager", "Cloud Engineer", "Cloud Architect", "Cloud Consultant") },
    @{"Name" = "Community Relations"; Positions = @("Community Relations Coordinator", "Community Relations Officer") },
    @{"Name" = "Compliance"; Positions = @("Compliance Officer", "Risk Analyst", "Auditor") },
    @{"Name" = "Consulting"; Positions = @("Consulting Manager", "Consultant") },
    @{"Name" = "Contracts"; Positions = @("Contracts Manager", "Contracts Coordinator", "Contracts Clerk") },
    @{"Name" = "Corporate Development"; Positions = @("Corporate Development Leader", "Corporate Development Strategist") },   
    @{"Name" = "C-Suite"; Positions = @("CIO", "CEO", "CFO", "CPO", "COO", "CISO", "CDPO", "CTO") }, 
    @{"Name" = "Customer Support"; Positions = @("Support Specialist", "Customer Service Rep", "Technical Support") },
    @{"Name" = "Data Science"; Positions = @("Data Science Manager", "Data Scientist", "Data Analyst", "Data Engineer") },
    @{"Name" = "Design"; Positions = @("Design Manager", "UX Designer", "Design Engineer", "Tester") },
    @{"Name" = "DevOps"; Positions = @("DevOps Engineer", "DevOps Specialist") },
    @{"Name" = "Engineering"; Positions = @("Engineering Manager", "Engineer", "Data Scientist", "Draughtsperson", "Design Engineer") },
    @{"Name" = "Event Management"; Positions = @("Event Coordinator", "Event Management Manager") },
    @{"Name" = "Facilities"; Positions = @("Facilities Manager", "Facilities Engineer", "Facilities Technician") },
    @{"Name" = "Field Services"; Positions = @("Field Services Manager", "Field Technician", "Field Engineer") },
    @{"Name" = "Government Affairs"; Positions = @("Government Affairs Liaison", "Government Relations Officer") },
    @{"Name" = "HSE"; Positions = @("HSE Manager", "Safety Inspector", "Environmental Health Officer", "HSE Advisor", "HSE Analyst") },
    @{"Name" = "Human Resources"; Positions = @("Human Resources Manager", "Payroll", "Business Partner", "HR Coordinator") },
    @{"Name" = "Innovation"; Positions = @("Innovation Strategist", "Innovation Researcher") },
    @{"Name" = "Internal Audit"; Positions = @("Internal Audit Manager", "Auditor", "Compliance Analyst") },
    @{"Name" = "Investor Relations"; Positions = @("Investor Relations Officer", "Communications Strategist") },
    @{"Name" = "IT"; Positions = @("Manager", "Support Tech", "Technician", "Architect", "HelpDesk", "Systems Admin", "Service Delivery", "Network Admin", "Server Admin", "Customer Success") },
    @{"Name" = "Legal"; Positions = @("Legal Manager", "Legal Advisor", "Paralegal", "Legal Counsel") },
    @{"Name" = "Learning & Development"; Positions = @("Learning & Development Manager", "L&D Trainer") },
    @{"Name" = "Logistics"; Positions = @("Logistics Coordinator", "Logistics Manager") },
    @{"Name" = "Marketing"; Positions = @("Marketing Manager", "Marketing Coordinator", "Marketing Assistant", "Marketing Specialist") },
    @{"Name" = "Medical Affairs"; Positions = @("Medical Officer", "Compliance") },
    @{"Name" = "Operations"; Positions = @("Operations Manager", "Operations Analyst") },
    @{"Name" = "Payroll"; Positions = @("Payroll Officer", "Payroll Analyst") },
    @{"Name" = "Planning"; Positions = @("Planning Manager", "Planning Engineer", "Planning Project Manager") },
    @{"Name" = "Product Management"; Positions = @("Product Management Manager", "Product Owner") },
    @{"Name" = "Procurement"; Positions = @("Procurement Manager", "Procurement Officer", "Buyer") },
    @{"Name" = "Project Management"; Positions = @("Project Management Manager", "Project Engineer") },
    @{"Name" = "Public Relations"; Positions = @("Public Relations Manager", "PR", "Communications Officer") },
    @{"Name" = "Publishing"; Positions = @("Publishing Manager", "Editor", "Content Coordinator") },
    @{"Name" = "Purchasing"; Positions = @("Purchasing Manager", "Purchasing Coordinator", "Buyer") },
    @{"Name" = "QA"; Positions = @("QA Manager", "QA Engineer", "QA Analyst") },
    @{"Name" = "Quality Control"; Positions = @("Quality Control Manager", "QC Inspector", "Quality Assurance Officer") },
    @{"Name" = "Recruiting"; Positions = @("Recruiting Manager", "Recruiter", "Talent Scout") },
    @{"Name" = "R&D"; Positions = @("R&D Manager", "Researcher", "Developer") },
    @{"Name" = "Risk Management"; Positions = @("Risk Management Manager", "Risk Analyst", "Compliance Officer") },
    @{"Name" = "Sales"; Positions = @("Sales Manager", "Sales Representative", "Sales Consultant") },
    @{"Name" = "Security"; Positions = @("Security Manager", "Security Officer", "Security Analyst") },
    @{"Name" = "Strategy"; Positions = @("Strategy Manager", "Strategy Analyst", "Strategy Consultant") },
    @{"Name" = "Systems Administration"; Positions = @("Systems Administration Manager", "SysAdmin", "Systems Engineer") },
    @{"Name" = "Talent Acquisition"; Positions = @("Talent Acquisition Manager", "Recruiter") },
    @{"Name" = "Technical Support"; Positions = @("Technical Support Manager", "Support Technician", "Helpdesk Analyst") },
    @{"Name" = "Training"; Positions = @("Training Manager", "Trainer", "Training Coordinator") },
    @{"Name" = "Workplace Services"; Positions = @("Workplace Services Manager", "Workplace Services Coordinator") }
)
  
#used for job titles i.e. design engineer IV
$departmentsJobLevels = @("I", "II", "III", "IV", "V")
  
#used for job titles i.e. design engineer IV
$departmentsJobLevels = @("I", "II", "III", "IV", "V")
  
#used for creating groups and group members
$enterpriseApps = @(
    @{ID = "APP"; Name = "Application Server"; Description = "Application Server" }    
    @{ID = "BCKP"; Name = "Backup"; Description = "Backup Solutions" }
    @{ID = "BI"; Name = "Business Intelligence"; Description = "Business Intelligence" }
    @{ID = "COLL"; Name = "Collaboration"; Description = "Collaboration" }
    @{ID = "CMDB"; Name = "Configuration Management"; Description = "Configuration Management" }
    @{ID = "CRM"; Name = "CRM"; Description = "Customer Relationship Management" }
    @{ID = "DBMS"; Name = "Database"; Description = "Database" }
    @{ID = "DHCP"; Name = "DHCP"; Description = "DHCP" }
    @{ID = "EPMP"; Name = "Endpoint Management"; Description = "Endpoint Management" }
    @{ID = "ENG"; Name = "Engineering Systems"; Description = "Engineering Systems" }
    @{ID = "ERP"; Name = "Enterprise Resource Planning"; Description = "Enterprise Resource Planning" }
    @{ID = "FTP"; Name = "FTP"; Description = "FTP Server" }
    @{ID = "HV"; Name = "Hyper-V"; Description = "Hyper-V" }    
    @{ID = "MAIL"; Name = "Email"; Description = "Email" }
    @{ID = "FSRV"; Name = "File Server"; Description = "File Server" }
    @{ID = "HRMS"; Name = "HRMS"; Description = "HRMS" }
    @{ID = "LIC"; Name = "License Server"; Description = "License Server" }
    @{ID = "LNX"; Name = "Linux"; Description = "Linux" }
    @{ID = "MON"; Name = "Monitoring"; Description = "Monitoring" }
    @{ID = "PRNT"; Name = "Print"; Description = "Print" }
    @{ID = "RDS"; Name = "Remote Desktop Services"; Description = "Remote Desktop Services" }    
    @{ID = "RPT"; Name = "Reporting"; Description = "Reporting" }
    @{ID = "SPS"; Name = "SharePoint"; Description = "SharePoint" }
    @{ID = "VDI"; Name = "Virtual Desktop"; Description = "Virtual Desktop" }
    @{ID = "VMWR"; Name = "VMware"; Description = "VMware" }
    @{ID = "WEB"; Name = "Webserver"; Description = "Webserver" }
)
  
#environments
$enterpriseAppsEnvironments = @("DEV", "QA", "PRD")
  
#osVersions
$osVersionsWindows = @("Windows Server 2016", "Windows Server 2019", "Windows Server 2022", "Windows Server 2025")
$osVersionsLinux = @("Ubuntu 22.04", "RHEL 9")
  
#SPNs for Kerberoasting either set by Rogue or Domain Admin
$servicePrincipalNames = @('CIFS', 'HOST', 'HTTP', 'MSSQlSvc', 'TERMSRV', 'W3SVC', 'WSMAN')
  
#groups the pam account will add employees to, uncomment to use them all
$confidentialGroups = @(
    @{ID = "1"; Name = "TLP - Red"; Description = "Restricted sharing - highly sensitive data" },
    @{ID = "2"; Name = "TLP - Amber"; Description = "Limited sharing - need-to-know basis" },
    @{ID = "3"; Name = "TLP - Green"; Description = "Community sharing - trusted group only" },
    @{ID = "4"; Name = "TLP - Clear"; Description = "Unrestricted sharing - public" }
)
  
#ou locations - possibly overkill
$ouConfidential = ($baseOUs | Where-Object { $_.Code -eq 'defConfidential' }).DN
$ouDepartments = ($baseOUs | Where-Object { $_.Code -eq 'defDepartments' }).DN
$ouEmployees = ($baseOUs | Where-Object { ($_.Code -eq 'defEmployees') }).DN
$ouEmployeesExpired = ($baseOUs | Where-Object { ($_.Code -eq 'defEmployeesExpired') }).DN
$ouEmployeesQuarantined = ($baseOUs | Where-Object { ($_.Code -eq 'defEmployeesQuarantined') }).DN
$ouEmployeesVIP = ($baseOUs | Where-Object { $_.Code -eq 'defEmployeesVips' }).DN
$ouGroups = ($baseOUs | Where-Object { $_.Code -eq 'defGroups' }).DN
$ouGroupsExpired = ($baseOUs | Where-Object { ($_.Code -eq 'defGroupsExpired') }).DN
$ouGroupsQuarantined = ($baseOUs | Where-Object { ($_.Code -eq 'defGroupsQuarantined') }).DN
$ouServers = ($baseOUs | Where-Object { ($_.Code -eq 'defServers') }).DN
$ouServersExpired = ($baseOUs | Where-Object { ($_.Code -eq 'defServersExpired') }).DN
$ouServersQuarantined = ($baseOUs | Where-Object { ($_.Code -eq 'defServersQuarantined') }).DN
$ouWorkstations = ($baseOUs | Where-Object { ($_.Code -eq 'defWorkstations') }).DN
$ouWorkstationsExpired = ($baseOUs | Where-Object { ($_.Code -eq 'defWorkstationsExpired') }).DN
$ouWorkstationsQuarantined = ($baseOUs | Where-Object { ($_.Code -eq 'defWorkstationsQuarantined') }).DN
$ouQuarantine = ($baseOUs | Where-Object { $_.Code -eq 'defQuarantine' }).DN
  
#new computers and users
$ouNewComputers = ($baseOUs | Where-Object { ($_.Code -eq 'defNewComputer') }).DN
$ouNewUsers = ($baseOUs | Where-Object { ($_.Code -eq 'defNewUser') }).DN
  
  
#all departments and all enterpriseApps
  
$selectedDepartments = $departments
  
$selectedEnterpriseApps = $enterpriseApps
  
#loop through all changes and wait
#set $TestOnly = $true before dot-sourcing to load functions/variables without running
if (-not $TestOnly) { 1..$actionsMax| ForEach-Object {
  
    $actionDate = Get-Date -Format "yyyy-MM-dd_HH:mm:ss"
  
    Write-Host "Action date: $actionDate"
  
    #get a random role
    $role = $rolesListWeighted | Get-Random -Count 1
  
    switch ($role) {
        desktop {
            $desktopAction = $desktopActionsWeighted | Get-Random -Count 1
            Write-Host "Invoke-DesktopAction -desktopAction $desktopAction"
            Invoke-DesktopAction -desktopAction $desktopAction
        }
        domainadmin {
            $domainAdminAction = $domainAdminActionsWeighted | Get-Random -Count 1
            Write-Host "Invoke-DomainAdminAction -domainAdminAction $DomainAdminAction"
            Invoke-DomainAdminAction -domainAdminAction $DomainAdminAction
        }
        helpdesk {
            $helpdeskAction = $helpdeskActionsWeighted | Get-Random -Count 1
            Write-Host "Invoke-HelpdeskAction -helpdeskAction $helpdeskAction"
            Invoke-HelpdeskAction -helpdeskAction $helpdeskAction
        }
        server {
            $serverAction = $serverActionsWeighted | Get-Random -Count 1
            Write-Host "Invoke-ServerAction -serverAction $serverAction"
            Invoke-ServerAction -serverAction $serverAction
        }
        service {
            $serviceAccount = $serviceAccountsWeighted | Get-Random -Count 1
            Write-Host "Invoke-ServiceAccountAction -serviceAccount $serviceAccount"
            Invoke-ServiceAccountAction -serviceAccount $serviceAccount
        }
    }
  
    Write-Host "--------------------------------------------------------------"
  
    Start-Sleep -Seconds $actionsWait
} } #end if (-not $TestOnly)

if (-not $TestOnly) { Stop-Transcript }
