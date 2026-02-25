<#
.SYNOPSIS
Action implementations for Automated Lab Activity Generator

.DESCRIPTION
Contains all 37 action implementations across 5 role types.
These are ported directly from the original script.
#>

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function New-ComplexPassword {
    Param(
        [parameter(Mandatory = $true)][ValidateRange(0, [int]::MaxValue)][Int]$passwordLength
    ) 
  
    if ($passwordLength -lt 14) {
        $passwordLength = 14
    }
  
    $passwordLength = $passwordLength - 4
    
    $charsLower = 97..122 | ForEach-object { [Char] $_ }     
    $cLower = $charsLower[(Get-Random $charsLower.count)]
  
    $charsUpper = 65..90 | ForEach-object { [Char] $_ } 
    $cUpper = $charsUpper[(Get-Random $charsUpper.count)]
  
    $charsNumber = 48..57 | ForEach-object { [Char] $_ } 
    $cNumber = $charsNumber[(Get-Random $charsNumber.count)]
  
    $charsSymbol = 35, 36, 40, 41, 42, 44, 45, 46, 47, 58, 59, 63, 64, 92, 95 | ForEach-object { [Char] $_ } 
    $cSymbol = $charsSymbol[(Get-Random $charsSymbol.count)]
    
    $ascii = $NULL
    for ($a = 48; $a -le 122; $a++) {
        $ascii += , [char][byte]$a
    }
   
    for ($loop = 1; $loop -le $passwordLength; $loop++) {
        $thePassword += ($ascii | GET-RANDOM)
    }
  
    $thePassword += $cLower + $cUpper + $cNumber + $cSymbol 
    $thePassword = ($thePassword -split '' | Sort-Object { Get-Random }) -join ''
   
    return $thePassword
}

function Remove-StringLatinCharacters {
    param (
        [string]$String
    )
  
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}

function New-RealADUser {
    param(        
        [System.Management.Automation.PSCredential]$Credential,
        [bool]$allowDES,
        [bool]$allowReversionEncryption,
        [bool]$passNotRequired
    )
  
    if ($null -ne $usersToCreate) {
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
        } while (Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue)
  
        $uUpnBase = "$uFirstName.$uLastName@$domainSuffix"
        $uUpn = $uUpnBase
        $counter = 1
        $duplicate = $false
  
        do {
            $existingUser = Get-ADUser -Filter { UserPrincipalName -eq $uUpn } -ErrorAction SilentlyContinue
  
            if ($existingUser) {
                $duplicate = $true
                $uUpn = "$uFirstName.$uLastName$counter@$domainSuffix"
                $counter++
            }
        } while ($existingUser)
   
        $uDepartment = Get-Random -InputObject ($selectedDepartments | Where-Object { $_.Name -ne "C-Suite" })
        $uDepartmentName = $uDepartment.Name
        $uDepartmentPosition = Get-Random -InputObject $uDepartment.Positions
        $uDepartmentLevel = Get-Random -InputObject $departmentsJobLevels
        $uJobTitle = "$uDepartmentPosition $uDepartmentLevel"
        $deptRoleGroupName = "$uDepartmentName - $uDepartmentPosition"              
        
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
            $userParameters["Name"] = "$uLastName($($counter-1)), $uFirstName"
            $userParameters["DisplayName"] = "$uLastName($($counter-1)), $uFirstName"
        }
        else {
            $userParameters["Name"] = "$uLastName, $uFirstName"
            $userParameters["DisplayName"] = "$uLastName, $uFirstName"
        }
        
        if ($allowReversionEncryption) { $userParameters["AllowReversiblePasswordEncryption"] = $true }
        if ($passNotRequired) { $userParameters["PasswordNotRequired"] = $true }
  
        $userObject = [PSCustomObject]$userParameters
  
        try {            
            if ($Credential -and $Credential.UserName) {
                $userObject | New-ADUser -Credential $Credential
            }
            else {
                $userObject | New-ADUser   
            }
  
            Start-Sleep -Milliseconds 100
            Write-Host "    + created user account: $SamAccountName"                     
        }
        catch {
            Write-Host "    - could not create user: $SamAccountName" -ForegroundColor Red
  
            if ($continueOnError -eq $false) {
                Write-Host "  - continue on error set to false, exiting" -ForegroundColor Red                    
                Exit
            }            
        }             
        
        try {
            if ($Credential -and $Credential.UserName) {
                Add-ADGroupMember -Identity $deptRoleGroupName -Members $SamAccountName -Credential $Credential      
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
            $NewUAC = $CurrentUAC -bor 0x200000
            
            if ($Credential -and $Credential.UserName) {
                Set-ADUser -Identity $newUser -Replace @{UserAccountControl = $NewUAC } -Credential $Credential
            }
            else {
                Set-ADUser -Identity $newUser -Replace @{UserAccountControl = $NewUAC }
            }
        }
  
        try {
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

# ============================================================================
# DESKTOP ACTIONS
# ============================================================================

function Invoke-DesktopAction {
    param(
        [string]$desktopAction
    )
    
    $accountDesktop = ($actionAccounts | Where-Object { $_.ID -eq "desktop" }).AccountName
    $desktopCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountDesktop, $passwordSecure
        
    switch ($desktopAction) {
  
        computerDelete {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter * -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) {                
                    $computerToAction = $computerToAction | Get-Random -Count 1
                }
  
                try {                    
                    Remove-ADComputer -Identity $computerToAction -Confirm:$false -Credential $desktopCredential    
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + deleted computer: $($computerToAction.Name)"    
                    }
                }
                catch {
                    Write-Host "      - could not delete computer: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        
        computerDisable {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $True } -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random -Count 1
                }
  
                try {
                    Set-ADComputer -Identity $computerToAction -Enabled $False -Credential $desktopCredential     
                    Move-ADObject -Identity $computerToAction -TargetPath $ouWorkstationsExpired -Credential $desktopCredential                
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + disabled computer: $($computerToAction.Name)"  
                    }
                }
                catch {
                    Write-Host "      - could not disable computer: $($computerToAction.Name)" -ForegroundColor Red 
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        
        computerEnable {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $False } -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random -Count 1
                }
  
                try {
                    Set-ADComputer -Identity $computerToAction -Enabled $True -Credential $desktopCredential     
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + enabled computer: $($computerToAction.Name)"  
                    }
                }
                catch {
                    Write-Host "      - could not enable computer: $($computerToAction.Name)" -ForegroundColor Red 
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        
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
  
            $computerOS = "Windows 11 Pro"
            $computerOSVersion = "10.0 (22621)"
  
            try {
                New-ADComputer -Name $computerName -DNSHostName $computerDNS -Description $computerDNS -OperatingSystem $computerOS -OperatingSystemVersion $computerOSVersion -Enabled $true -Path $ouWorkstationTarget -Credential $desktopCredential 
                
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
                Write-Host "      - could create account with DES encryption enabled" -ForegroundColor Red
            }
        }
        
        userNewReversibleEncryption {
            try {
                New-RealADUser -allowReversionEncryption $true -Credential $desktopCredential             
                Write-Host "      + reversible encryption allowed"  
            }
            catch {
                Write-Host "      - could not create an account with reversible encryption allowed" -ForegroundColor Red
            }
        }   
        
        userNewPasswordNotRequired {
            try {
                New-RealADUser -passNotRequired $true -Credential $desktopCredential             
                Write-Host "      + password not required allowed"  
            }
            catch {
                Write-Host "      - could not create an account with password not required allowed" -ForegroundColor Red
            }
        }                          
        
        userDisable {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) {
                    $userToAction = $userToAction | Get-Random -Count 1
                }
  
                try {
                    $userToAction | Set-ADUser -Enabled $False -Credential $desktopCredential  
                    Move-ADObject -Identity $userToAction -TargetPath $ouEmployeesExpired -Credential $desktopCredential 
                   
                    if ($showAllActions -eq $True) {
                        Write-Host "    + disabled user: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    Write-Host "    + could not disable user: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no enabled users found" -ForegroundColor Yellow
            }
        }
        
        updateDepartmentGroup {
            $uUser = Get-ADUser -Filter { Enabled -eq $True } -SearchBase $ouEmployees -SearchScope OneLevel -Properties MemberOf, Title, Department | Get-Random -Count 1
  
            if ($null -ne $uUser) {
  
                $uDepartment = Get-Random -InputObject ($selectedDepartments | Where-Object { $_.Name -ne "C-Suite" })
                $uDepartmentName = $uDepartment.Name
                $uDepartmentPosition = Get-Random -InputObject $uDepartment.Positions
                $uDepartmentLevel = Get-Random -InputObject $departmentsJobLevels
                $uJobTitle = "$uDepartmentPosition $uDepartmentLevel"
                $deptRoleGroupName = "$uDepartmentName - $uDepartmentPosition"  
  
                Write-Host "    + updating department for user: $($uUser.Name) [$($uUser.SamAccountName)]"
  
                $uUser.MemberOf | ForEach-Object {
                    $group = Get-ADGroup $_ -Properties Name
    
                    if ($group.Name -like "$($uUser.Department)*") {
  
                        try {
                            Remove-ADGroupMember -Identity $group.Name -Members $uUser -Confirm:$false -Credential $desktopCredential                
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
                    Set-ADUser -Identity $uUser -Title $uJobTitle -Department $uDepartmentName -Description $uJobTitle -Credential $desktopCredential
  
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
                    Add-ADGroupMember -Identity $deptRoleGroupName -Members $uUser -Credential $desktopCredential   
        
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

# ============================================================================
# DOMAIN ADMIN ACTIONS
# ============================================================================

function Invoke-DomainAdminAction {
    param(
        [string]$domainAdminAction
    )
  
    $accountDomainAdmin = ($actionAccounts | Where-Object { $_.ID -eq "domainadmin" }).AccountName
    $domainAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountDomainAdmin, $passwordSecure
        
    switch ($domainAdminAction) {      
          
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
  
            try {    
                $dnsRecordCheck = Get-DnsServerResourceRecord -Name $dnsRecordToCreate -ZoneName $domainSuffix -WarningAction SilentlyContinue -ErrorAction SilentlyContinue                    
            }
            catch {
                $dnsRecordCheck = $null
            }
  
            if ($null -eq $dnsRecordCheck) {
  
                Write-Host "      + creating dns record: $dnsRecordToCreate"
  
                $result = Invoke-Command -ComputerName $dcName -ArgumentList $dnsRecordToCreate, $domainSuffix -Credential $domainAdminCredential -ScriptBlock {
  
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
                    Write-Host "        - could not create dns record: $dnsRecordToCreate" -ForegroundColor Red
                }
            }
            elseif ($dnsRecordCheck -eq $true) {
                if ($showAllActions -eq $True) {
                    Write-Host "        - dns record already exists: $dnsRecordToCreate"                
                }
            }
        }   
        
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
                $result = Invoke-Command -ComputerName $dcName -ArgumentList $dnsRecordToDelete, $domainSuffix -Credential $domainAdminCredential -ScriptBlock {
                    
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
                
                $result = Invoke-Command -ComputerName $dcName -Credential $domainAdminCredential -ArgumentList $ouServers, $gpoServerNL -ScriptBlock {
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
        
        gpoNew {            
            $gposToCreate = @("Servers - ALL - Windows Update", "Servers - ALL - Temporary", "Servers - ALL - Legacy", "Servers - ALL - Blank")
            
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
                    $result = Invoke-Command -ComputerName $dcName -ArgumentList $gpoName -Credential $domainAdminCredential -ScriptBlock {
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
                $result = Invoke-Command -ComputerName $dcName -Credential $domainAdminCredential -ArgumentList $ouServers, $gpoServerLinked -ScriptBlock {
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
        
        newSubnet {
            try {
                $randomIP = "{0}.{1}.{2}.{3}" -f (Get-Random -Minimum 1 -Maximum 254),
                (Get-Random -Minimum 0 -Maximum 255),
                (Get-Random -Minimum 0 -Maximum 255),
                (Get-Random -Minimum 1 -Maximum 254)
  
                $randomIpNetmask = $randomIP -replace "\d{1,3}$", "0/24"
                
                $randomIpNetmaskLocation = "Subnet: $randomIpNetmask"
  
                New-ADReplicationSubnet -Name $randomIpNetmask -Location $randomIpNetmaskLocation -Credential $domainAdminCredential
                
                if ($showAllActions -eq $true) {
                    Write-Host "      + created subnet: $randomIpNetmask"
                }
            }
            catch {
                Write-Host "      - could not create subnet: $randomIpNetmask" -ForegroundColor Red
            }
        }
        
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
                    $servicePrincipalName = $servicePrincipalName + '/' + $computerToAction.DNSHostName
                    Set-ADComputer -Identity $computerToAction -ServicePrincipalNames @{Add = "$servicePrincipalName" } -Credential $domainAdminCredential
                    
                    Write-Host "      + set SPN: $servicePrincipalName on $($computerToAction.Name)"                    
                }
                catch {
                    Write-Host "      - could not set SPN: $servicePrincipalName on $($computerToAction.Name)" -ForegroundColor Red
                }
            }
        }                
    }
}

# ============================================================================
# HELPDESK ACTIONS
# ============================================================================

function Invoke-HelpdeskAction {
    param(
        [string]$helpdeskAction
    )
  
    $accountHelpdesk = ($actionAccounts | Where-Object { $_.ID -eq "helpdesk" }).AccountName
    $helpdeskCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountHelpdesk, $passwordSecure
  
    switch ($helpdeskAction) {
        
        userDisable {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) {
                    $userToAction = $userToAction | Get-Random
                }
                                
                try {
                    Set-ADUser -Identity $userToAction -Enabled $False -Credential $helpdeskCredential 
                    
                    if ($showAllActions -eq $True) {    
                        Write-Host "      + disabled user: $($userToAction.SamAccountName)"       
                    }
                }
                catch {
                    Write-Host "      - could not disable user: $($userToAction.SamAccountName)" -ForegroundColor Red  
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }
        
        userEnable {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $False } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) {
                    $userToAction = $userToAction | Get-Random
                }
                try {
                    Set-ADUser -identity $userToAction -Enabled $True -Credential $helpdeskCredential      
                    
                    if ($showAllActions -eq $True) {
                        Write-Host "      + enabled user: $($userToAction.SamAccountName)"  
                    }
                }
                catch {
                    Write-Host "      - could not enable user: $($userToAction.SamAccountName)" -ForegroundColor Red 
                }
            }
            else {
                Write-Host "      ~ no disabled users found" -ForegroundColor Yellow
            }
        }
        
        computerDisable {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $True } -SearchBase $ouWorkstations
            
            if ($null -ne $computerToAction) {
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random
                }
  
                try {
                    Set-ADComputer -Identity $computerToAction -Enabled $False -Credential $helpdeskCredential 
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + disabled computer: $($computerToAction.Name)"  
                    }
                }
                catch {
                    Write-Host "      - could not disable computer: $($computerToAction.Name)" -ForegroundColor Red 
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        
        computerEnable {       
            $computerToAction = $null    
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $False } -SearchBase $ouWorkstations
  
            if ($null -ne $computerToAction) {                
                if ($computerToAction.count -gt 1) { 
                    $computerToAction = $computerToAction | Get-Random
                }
  
                try {
                    Set-ADComputer -Identity $computerToAction -Enabled $True -Credential $helpdeskCredential 
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + enabled computer: $($computerToAction.Name)"  
                    }
                }
                catch {
                    Write-Host "      - could not enable computer: $($computerToAction.Name)" -ForegroundColor Red 
                }
            }
            else {
                Write-Host "      ~ no computers found" -ForegroundColor Yellow
            }
        }
        
        passwordAbnormalRefresh {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
  
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }                
                
                try {
                    $userToAction | Set-ADUser -ChangePasswordAtLogon $True -Credential $helpdeskCredential     
                    
                    Start-Sleep -Seconds 10
  
                    $userToAction | Set-ADUser -ChangePasswordAtLogon $False -Credential $helpdeskCredential    
                     
                    Write-Host "      + abnormaly refreshed password: $($userToAction.SamAccountName)"                                   
                }
                catch {
                    Write-Host "      - could not abnormaly refresh password: $($userToAction.SamAccountName)" -ForegroundColor Red    
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }        
        
        passwordAtNextLogon {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
  
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }                
                
                try {
                    $userToAction | Set-ADUser -ChangePasswordAtLogon $True -Credential $helpdeskCredential     
                    
                    if ($showAllActions -eq $True) { 
                        Write-Host "      + change password at next logon set: $($userToAction.SamAccountName)"               
                    }
                }
                catch {
                    Write-Host "      - could not set change password at next logon: $($userToAction.SamAccountName)" -ForegroundColor Red    
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }
        
        passwordReset {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            $userPassword = New-ComplexPassword -passwordLength 14
  
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }              
  
                try {
                    Set-ADAccountPassword -Identity $userToAction -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$userPassword" -Force) -Credential $helpdeskCredential  
                    
                    if ($showAllActions -eq $True) { 
                        Write-Host "      + changed password: $($userToAction.SamAccountName)"        
                    }
                }
                catch {
                    Write-Host "      - could not change password: $($userToAction.SamAccountName)" -ForegroundColor Red   
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }     
        
        passwordResetInDescription {
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees -SearchScope OneLevel
            $userPassword = New-ComplexPassword -passwordLength 14
  
            if ($null -ne $userToAction) {                
  
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }              
  
                try {
                    Set-ADAccountPassword -Identity $userToAction -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$userPassword" -Force) -Credential $helpdeskCredential  
                    Set-ADUser -Identity $userToAction -Description "Password: $userPassword" -Credential $helpdeskCredential  
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + changed password and updated user description: $($userToAction.SamAccountName)"        
                    }
                }
                catch {
                    Write-Host "      - could not set password in description: $($userToAction.SamAccountName)" -ForegroundColor Red                     
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }   
        
        updateConfidentialGroup {
            $pamGroup = ($confidentialGroups | Get-Random).Name           
  
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees
            
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
            } 
            
            try {
                Add-ADGroupMember -Identity $pamGroup -Members $userToAction -Credential $helpdeskCredential
  
                Write-Host "    + added user: $($userToAction.SamAccountName) to $pamGroup"                          
            }
            catch {
                Write-Host "    - could not add user: $($userToAction.SamAccountName) to $pamGroup" -ForegroundColor Red          
            }                 
        }   
        
        userUpdateDescription {
            $userToAction = $null          
            $userToAction = Get-ADUser -Filter { Description -like "*" } -Properties Description -SearchBase $ouEmployees -SearchScope OneLevel
            
            if ($null -ne $userToAction) {
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
                try {
                    $userToActionDescription = $userToAction.Description + ' I'
                    $userToAction | Set-ADUser -Description $userToActionDescription -Credential $helpdeskCredential   
  
                    if ($showAllActions -eq $True) {
                        Write-Host "      + changed description: $($userToAction.SamAccountName)"             
                    }
                }
                catch {
                    Write-Host "      - could not change description: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no users found" -ForegroundColor Yellow
            }
        }        
    }
}

# ============================================================================
# SERVER ACTIONS
# ============================================================================

function Invoke-ServerAction {
    param(
        [string]$serverAction
    )
  
    $accountServer = ($actionAccounts | Where-Object { $_.ID -eq "server" }).AccountName
    $serverCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $accountServer, $passwordSecure
  
    switch ($serverAction) {
        
        computerDelete {
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter * -SearchBase $ouServers
            
            if ($null -ne $computerToAction) {
  
                if ($computerToAction.Count -gt 1) {
                    $computerToAction = $computerToAction[(Get-Random -Minimum 0 -Maximum $computerToAction.Count)]
                }
  
                try {
                    Remove-ADComputer -Identity $computerToAction -Confirm:$False -Credential $serverCredential      
                    
                    if ($showAllActions -eq $True) {               
                        Write-Host "      + server deleted: $($computerToAction.Name)"
                    }
                }
                catch {
                    Write-Host "      - could not delete server: $($computerToAction.Name)" -ForegroundColor Red
                }
            } 
            else {
                Write-Host "      ~ no servers found" -ForegroundColor Yellow
            }
        }
        
        computerDisable {        
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $True } -SearchBase $ouServers
            
            if ($null -ne $computerToAction) {
  
                if ($computerToAction.Count -gt 1) {
                    $computerToAction = $computerToAction[(Get-Random -Minimum 0 -Maximum $computerToAction.Count)]
                }
  
                try {
                    Set-ADComputer -Identity $computerToAction -Enabled $False -Credential $serverCredential 
  
                    if ($showAllActions -eq $True) { 
                        Write-Host "      + server disabled: $($computerToAction.Name)"  
                    }
                }
                catch {
                    Write-Host "      - could not disable server: $($computerToAction.Name)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "      ~ no servers found" -ForegroundColor Yellow
            }      
        }
        
        computerEnable {        
            $computerToAction = $null
            $computerToAction = Get-ADComputer -Filter { Enabled -eq $False } -SearchBase $ouServers
            
            if ($null -ne $computerToAction) {
  
                if ($computerToAction.Count -gt 1) {
                    $computerToAction = $computerToAction[(Get-Random -Minimum 0 -Maximum $computerToAction.Count)]
                }
  
                try {
                    Set-ADComputer -Identity $computerToAction -Enabled $True -Credential $serverCredential 
  
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
        
        computerNew {        
            $enterpriseApp = $selectedEnterpriseApps | Get-Random
  
            $appEnv = $enterpriseAppsEnvironments | Get-Random
            $appName = $enterpriseApp.Name
            $appCode = $enterpriseApp.Id
            $ouAppPath = "OU=$appName,$ouServers"
            
            try {
                Get-ADOrganizationalUnit -Identity $ouAppPath -ErrorAction Stop | Out-Null
            }
            catch {
                try {
                    New-ADOrganizationalUnit -Name $appName -Path $ouServers -Credential $serverCredential
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
  
                try {
                    Get-ADComputer -Identity $computerName | Out-Null
                    $match = $true
                    $i++
                }
                catch {
                    $match = $false   
                }
            }
  
            $computerDNS = "$computerName.$domainSuffix"
            
            try {
                New-ADComputer -Name $computerName -SAMAccountName $computerName -DNSHostName $computerDNS -Path $ouAppPath -OperatingSystem $osVersion -Description "$appName $appEnvserver"                                                         
                
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
					New-ADGroup -Name $serverGroup -GroupScope Global -GroupCategory Security -Path $ouGroups -Credential $serverCredential
				}
				catch {
					# Group may already exist or other error
				}
			}
			
            try {
                Add-ADGroupMember -Identity $serverGroup -Members "$computerName$"  
            }
            catch {
                Write-Host "            - server could not be added to server group" -ForegroundColor Red
            }
        }
        
        groupNewMember {        
            $groupToUpdate = Get-ADGroup -Filter { Name -like "*-Users" } -SearchBase $ouGroups
  
  
            if ($null -ne $groupToUpdate) {
                
                $groupToUpdate = $GroupToUpdate | Get-Random 
  
                $userToAction = $null
                $userToAction = Get-ADUser -Filter * -SearchBase $ouEmployees
  
                if ($null -ne $userToAction) {
                    if ($userToAction.Count -gt 1) {
                        $userToAction = $userToAction | Get-Random      
                    }
                
                    try {
                        Add-ADGroupMember -Identity $groupToUpdate -Members $userToAction -Credential $serverCredential 
  
                        if ($showAllActions -eq $True) {
                            Write-Host "      + added user: $($userToAction.SamAccountName) to $($groupToUpdate.Name)"
                        }
                    }
                    catch {
                        Write-Host "      - could not add:  $($userToAction.SamAccountName) to $($groupToUpdate.Name)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "      ~ no users found" -ForegroundColor Yellow
                }                            
            }
            else {
                Write-Host "      ~ no groups found" -ForegroundColor Yellow
            }  
        }
    }
}

# ============================================================================
# SERVICE ACCOUNT ACTIONS
# ============================================================================

function Invoke-ServiceAccountAction {  
    param(
        [string]$serviceAccount 
    )
   
    $serviceAccountCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $serviceAccount, $passwordSecure
  
    switch ($serviceAccount) {
        
        svc-callmanager {            
            $userToAction = $null
            $userToAction = Get-ADUser -Filter * -SearchBase $ouEmployees
            
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
  
                $userIPPhone = "+" + (Get-Random -Minimum 123456789012 -Maximum 923456789012).ToString('00000')
  
                try {
                    $userToAction | Set-ADuser -Replace @{ipPhone = $userIPPhone } -Credential $serviceAccountCredential 
  
                    if ($showAllActions -eq $True) {
                        Write-Host "    + svc-callmanager updated: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    Write-Host "    - svc-callmanager could not update: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "    - no valid accounts found, skipping" -ForegroundColor Yellow
            }         
        }                     
        
        svc-offboarding {
            $userToAction = $null
            
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees 
           
            if ($null -eq $userToAction) {
                Write-Host "    - no enabled accounts found, skipping" -ForegroundColor Yellow
            } 
            elseif ($null -ne $userToAction) {
  
                $userToAction = $userToAction | Get-Random
  
                try {
                    $userToAction | Set-ADUser -Enabled $False -Credential $serviceAccountCredential 
                    Move-ADObject -Identity $userToAction -TargetPath $ouEmployeesExpired -Credential $serviceAccountCredential
                    
                    if ($showAllActions -eq $True) {
                        Write-Host "    + svc-offboarding disabled: $($userToAction.SamAccountName)"
                    }
                }
                catch {
                    Write-Host "    - svc-offboarding could not disable: $($userToAction.SamAccountName)" -ForegroundColor Red
                }
            }
        }
        
        svc-onboarding {
            $userToAction = $null
            $userToAction = New-RealADUser -Credential $serviceAccountCredential           
        }
        
        svc-pam {
            $pamGroup = ($confidentialGroups | Get-Random).Name           
  
            $userToAction = $null
            $userToAction = Get-ADUser -Filter { Enabled -eq $True } -Properties Enabled -SearchBase $ouEmployees
            
            if ($null -ne $userToAction) {                
                if ($userToAction.count -gt 1) { 
                    $userToAction = $userToAction | Get-Random
                }   
            } 
            
            try {
                Add-ADGroupMember -Identity $pamGroup -Members $userToAction -Credential $serviceAccountCredential 
  
                Write-Host "    + svc-pam added user: $($userToAction.SamAccountName) to $pamGroup"                          
            }
            catch {
                Write-Host "    - svc-pam could not add user: $($userToAction.SamAccountName) to $pamGroup" -ForegroundColor Red          
            }            
        }          
    }
}
