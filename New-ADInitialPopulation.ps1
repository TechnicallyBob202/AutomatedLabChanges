<#
.SYNOPSIS
    Creates initial population of users and computers for Semperis DSP demo lab
.DESCRIPTION
    Creates users using randomuser.me API and computers matching original distribution
    Adds users to department groups and computers to enterprise app groups
.PARAMETER UserCount
    Number of regular employees to create (default: 100, max: 2275)
.PARAMETER CreateServers
    Create servers matching original distribution (524 total)
.PARAMETER CreateWorkstations
    Create workstations matching original distribution (2950 total)
.PARAMETER WhatIf
    Show what would be created without making changes
#>

param(
    [int]$UserCount = 100,
    [switch]$CreateServers,
    [switch]$CreateWorkstations,
    [string]$Password = "superSECURE!",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================================="  -ForegroundColor Green
Write-Host "        AD Initial Population Script" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Users to create: $UserCount"
Write-Host "Create servers: $CreateServers"
Write-Host "Create workstations: $CreateWorkstations"
if ($WhatIf) { Write-Host "MODE: WHATIF (no changes will be made)" -ForegroundColor Yellow }
Write-Host "==============================================================`n" -ForegroundColor Green

# ============================================================
# CONNECT TO DOMAIN
# ============================================================
try {
    $domain = Get-ADDomain
    $domainDN = $domain.DistinguishedName
    $domainSuffix = $domain.DNSRoot
    Write-Host "Connected to domain: $domainSuffix" -ForegroundColor Green
}
catch {
    Write-Host "Could not connect to domain" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================
# CONFIGURATION - Server Distribution (Original: 524 servers)
# ============================================================
$serverDistribution = @{
    "Application Server" = 21
    "Backup" = 22
    "Business Intelligence" = 20
    "Collaboration" = 20
    "Configuration Management" = 21
    "CRM" = 20
    "Database" = 23
    "DHCP" = 20
    "Email" = 21
    "Endpoint Management" = 20
    "Engineering Systems" = 21
    "Enterprise Resource Planning" = 21
    "File Server" = 21  # Changed from "FileServer" to match OU name
    "FTP" = 20
    "HRMS" = 21
    "Hyper-V" = 21
    "License Server" = 20
    "Linux" = 21
    "Monitoring" = 21
    "Print" = 20
    "Remote Desktop Services" = 21
    "Reporting" = 20
    "SharePoint" = 21
    "Virtual Desktop" = 20
    "VMware" = 21
    "Webserver" = 21
}

# Server name prefixes (based on Automated-Lab-Changes script)
$serverPrefixes = @{
    "Application Server" = "APP"
    "Backup" = "BCK"
    "Business Intelligence" = "BIN"
    "Collaboration" = "COL"
    "Configuration Management" = "CFG"
    "CRM" = "CRM"
    "Database" = "DBS"
    "DHCP" = "DCP"
    "Email" = "EML"
    "Endpoint Management" = "EPM"
    "Engineering Systems" = "ENG"
    "Enterprise Resource Planning" = "ERP"
    "File Server" = "FIL"
    "FTP" = "FTP"
    "HRMS" = "HRM"
    "Hyper-V" = "HYP"
    "License Server" = "LIC"
    "Linux" = "LNX"
    "Monitoring" = "MON"
    "Print" = "PRT"
    "Remote Desktop Services" = "RDS"
    "Reporting" = "RPT"
    "SharePoint" = "SHP"
    "Virtual Desktop" = "VDI"
    "VMware" = "VMW"
    "Webserver" = "WEB"
}

# Server environments (DEV, QA, PRD distribution)
$environments = @("DEV", "QA", "PRD")

# ============================================================
# CONFIGURATION - Workstation Distribution (Original: 2950)
# ============================================================
$workstationDistribution = @{
    "Engineering" = 610
    "Field" = 605
    "Kiosks" = 575
    "VDI" = 557
    "Workstations" = 603  # Standard workstations (root OU)
}

$workstationPrefixes = @{
    "Engineering" = "ENG"
    "Field" = "FLD"
    "Kiosks" = "KSK"
    "VDI" = "VDI"
    "Workstations" = "WKS"
}

# ============================================================
# CONFIGURATION - Department Groups (for user assignment)
# ============================================================
$departments = @(
    "Accounting", "Administration", "Business Development", "Cloud Services",
    "Community Relations", "Compliance", "Consulting", "Contracts",
    "Corporate Development", "C-Suite", "Customer Support", "Data Science",
    "Design", "DevOps", "Engineering", "Event Management", "Facilities",
    "Field Services", "Government Affairs", "HSE", "Human Resources",
    "Innovation", "Internal Audit", "Investor Relations", "IT", "Legal",
    "Learning & Development", "Logistics", "Marketing", "Medical Affairs",
    "Operations", "Payroll", "Planning", "Product Management", "Procurement",
    "Project Management", "Public Relations", "Publishing", "Purchasing",
    "QA", "Quality Control", "Recruiting", "R&D", "Risk Management",
    "Sales", "Security", "Strategy", "Systems Administration",
    "Talent Acquisition", "Technical Support", "Training", "Workplace Services"
)

# ============================================================
# STATISTICS
# ============================================================
$stats = @{
    UsersCreated = 0
    UsersFailed = 0
    ServersCreated = 0
    ServersFailed = 0
    WorkstationsCreated = 0
    WorkstationsFailed = 0
    MembershipsAdded = 0
    MembershipsFailed = 0
}

# ============================================================
# HELPER FUNCTION - Generate Random String
# ============================================================
function Get-RandomString {
    param([int]$Length = 9)
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $random = 1..$Length | ForEach-Object { Get-Random -Maximum $chars.Length }
    return -join ($random | ForEach-Object { $chars[$_] })
}

# ============================================================
# CREATE USERS
# ============================================================
if ($UserCount -gt 0) {
    Write-Host "`n=============================================================="  -ForegroundColor Cyan
    Write-Host "Creating Users ($UserCount users)" -ForegroundColor Cyan
    Write-Host "==============================================================`n" -ForegroundColor Cyan

    # Fetch users from randomuser.me API
    Write-Host "Fetching user data from randomuser.me API..." -ForegroundColor Cyan
    
    try {
        $userCountryCodes = "GB,IE,NZ,US"
        $apiUrl = "https://randomuser.me/api/?results=$UserCount&inc=name,location,nat&nat=$userCountryCodes"
        $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        $randomUsers = $response.results
        Write-Host "  Fetched $($randomUsers.Count) user profiles" -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to fetch from API: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Continuing without users..." -ForegroundColor Yellow
        $randomUsers = @()
    }

    $userOU = "OU=Employees,OU=_SemperisDSP,$domainDN"
    $passwordSecure = ConvertTo-SecureString -String $Password -AsPlainText -Force
    
    # Start user ID at a reasonable number
    $userIdCounter = 1

    foreach ($randomUser in $randomUsers) {
        
        # Generate employee ID (E000001, E000002, etc.)
        $employeeId = "E{0:D6}" -f $userIdCounter
        
        # Build name
        $firstName = $randomUser.name.first
        $lastName = $randomUser.name.last
        $displayName = "$firstName $lastName"
        
        # Generate username (first initial + lastname, lowercase)
        $username = "$($firstName.Substring(0,1))$lastName".ToLower() -replace '[^a-z0-9]', ''
        
        # Ensure unique username
        $baseUsername = $username
        $counter = 1
        while ($true) {
            try {
                Get-ADUser -Identity $username -ErrorAction Stop | Out-Null
                # User exists, try next variant
                $username = "$baseUsername$counter"
                $counter++
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                # Username available
                break
            }
            catch {
                Write-Host "  Error checking username $username : $($_.Exception.Message)" -ForegroundColor Red
                break
            }
        }
        
        $upn = "$username@$domainSuffix"
        
        # Pick random department
        $department = Get-Random -InputObject $departments
        
        Write-Host "Processing: $displayName [$username] - $department" -ForegroundColor White
        
        if (-not $WhatIf) {
            try {
                $userParams = @{
                    Name = $displayName
                    GivenName = $firstName
                    Surname = $lastName
                    SamAccountName = $username
                    UserPrincipalName = $upn
                    DisplayName = $displayName
                    Description = $department
                    Department = $department
                    EmployeeID = $employeeId
                    Path = $userOU
                    AccountPassword = $passwordSecure
                    Enabled = $true
                    ChangePasswordAtLogon = $false
                    PasswordNeverExpires = $true
                }
                
                # Add address if available
                if ($randomUser.location.street.name) {
                    $userParams['StreetAddress'] = "$($randomUser.location.street.number) $($randomUser.location.street.name)"
                }
                if ($randomUser.location.city) {
                    $userParams['City'] = $randomUser.location.city
                }
                if ($randomUser.location.state) {
                    $userParams['State'] = $randomUser.location.state
                }
                if ($randomUser.location.postcode) {
                    $userParams['PostalCode'] = $randomUser.location.postcode.ToString()
                }
                if ($randomUser.location.country) {
                    $userParams['Country'] = $randomUser.location.country
                }
                
                New-ADUser @userParams
                
                Write-Host "  Created user: $username (ID: $employeeId)" -ForegroundColor Green
                $stats.UsersCreated++
                
                # Add to department group (if exists)
                try {
                    # Try to find a department group
                    $deptGroups = Get-ADGroup -Filter "Name -like '$department*'" -SearchBase "OU=Departments,OU=_SemperisDSP,$domainDN" -ErrorAction SilentlyContinue
                    
                    if ($deptGroups) {
                        $deptGroup = $deptGroups | Select-Object -First 1
                        Add-ADGroupMember -Identity $deptGroup.SamAccountName -Members $username -ErrorAction Stop
                        Write-Host "    Added to group: $($deptGroup.Name)" -ForegroundColor Gray
                        $stats.MembershipsAdded++
                    }
                }
                catch {
                    # Silently continue if group doesn't exist
                }
                
                $userIdCounter++
            }
            catch {
                Write-Host "  Failed to create user" -ForegroundColor Red
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
                $stats.UsersFailed++
            }
        }
        else {
            Write-Host "  [WHATIF] Would create user: $username" -ForegroundColor Cyan
            $stats.UsersCreated++
            $userIdCounter++
        }
    }

    Write-Host "`n==============================================================`n" -ForegroundColor Cyan
}

# ============================================================
# CREATE SERVERS
# ============================================================
if ($CreateServers) {
    Write-Host "`n=============================================================="  -ForegroundColor Cyan
    $totalServers = ($serverDistribution.Values | Measure-Object -Sum).Sum
    Write-Host "Creating Servers ($totalServers total across 26 categories)" -ForegroundColor Cyan
    Write-Host "==============================================================`n" -ForegroundColor Cyan

    foreach ($category in $serverDistribution.Keys) {
        
        $count = $serverDistribution[$category]
        $prefix = $serverPrefixes[$category]
        $ouPath = "OU=$category,OU=Servers,OU=_SemperisDSP,$domainDN"
        
        Write-Host "Category: $category ($count servers)" -ForegroundColor Cyan
        
        # Verify OU exists
        try {
            Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host "  OU not found: $ouPath" -ForegroundColor Red
            Write-Host "  Skipping category..." -ForegroundColor Yellow
            continue
        }
        
# Distribute servers across environments
        $serversPerEnv = [Math]::Floor($count / 3)
        $remainder = $count % 3
        
        $devExtra = if ($remainder -ge 1) { 1 } else { 0 }
        $qaExtra = if ($remainder -ge 2) { 1 } else { 0 }
        
        $envCounts = @{
            "DEV" = $serversPerEnv + $devExtra
            "QA" = $serversPerEnv + $qaExtra
            "PRD" = $serversPerEnv
        }
        
        foreach ($env in $environments) {
            
            $envCount = $envCounts[$env]
            
            for ($i = 1; $i -le $envCount; $i++) {
                
                $serverName = "$prefix$env{0:D3}" -f $i
                
                Write-Host "  Creating: $serverName" -ForegroundColor White
                
                if (-not $WhatIf) {
                    try {
                        # Check if computer already exists
                        try {
                            Get-ADComputer -Identity $serverName -ErrorAction Stop | Out-Null
                            Write-Host "    Computer already exists, skipping" -ForegroundColor Yellow
                            continue
                        }
                        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                            # Computer doesn't exist, continue
                        }
                        
                        $computerParams = @{
                            Name = $serverName
                            SamAccountName = "$serverName$"
                            Path = $ouPath
                            Description = "$category $env Server"
                            Enabled = $true
                        }
                        
                        New-ADComputer @computerParams
                        
                        Write-Host "    Created server: $serverName" -ForegroundColor Green
                        $stats.ServersCreated++
                        
                        # Add to server group
                        try {
                            $groupName = "$category-$env-Servers"
                            $group = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction Stop
                            Add-ADGroupMember -Identity $group.SamAccountName -Members "$serverName$" -ErrorAction Stop
                            Write-Host "      Added to group: $groupName" -ForegroundColor Gray
                            $stats.MembershipsAdded++
                        }
                        catch {
                            # Group might not exist, continue
                        }
                    }
                    catch {
                        Write-Host "    Failed to create server" -ForegroundColor Red
                        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
                        $stats.ServersFailed++
                    }
                }
                else {
                    Write-Host "    [WHATIF] Would create server: $serverName" -ForegroundColor Cyan
                    $stats.ServersCreated++
                }
            }
        }
    }

    Write-Host "`n==============================================================`n" -ForegroundColor Cyan
}

# ============================================================
# CREATE WORKSTATIONS
# ============================================================
if ($CreateWorkstations) {
    Write-Host "`n=============================================================="  -ForegroundColor Cyan
    $totalWorkstations = ($workstationDistribution.Values | Measure-Object -Sum).Sum
    Write-Host "Creating Workstations ($totalWorkstations total across 5 categories)" -ForegroundColor Cyan
    Write-Host "==============================================================`n" -ForegroundColor Cyan

    foreach ($category in $workstationDistribution.Keys) {
        
        $count = $workstationDistribution[$category]
        $prefix = $workstationPrefixes[$category]
        
        # Determine OU path
        if ($category -eq "Workstations") {
            $ouPath = "OU=Workstations,OU=_SemperisDSP,$domainDN"
        }
        else {
            $ouPath = "OU=$category,OU=Workstations,OU=_SemperisDSP,$domainDN"
        }
        
        Write-Host "Category: $category ($count workstations)" -ForegroundColor Cyan
        
        # Verify OU exists
        try {
            Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host "  OU not found: $ouPath" -ForegroundColor Red
            Write-Host "  Skipping category..." -ForegroundColor Yellow
            continue
        }
        
        for ($i = 1; $i -le $count; $i++) {
            
            # Generate workstation name (e.g., ENG-ABCDEF123 + 2 digits)
            $randomPart = Get-RandomString -Length 9
            $numberPart = Get-Random -Minimum 10 -Maximum 99
            $workstationName = "$prefix-$randomPart$numberPart"
            
            if (($i % 100) -eq 0) {
                Write-Host "  Progress: $i / $count" -ForegroundColor Gray
            }
            
            if (-not $WhatIf) {
                try {
                    # Check if computer already exists
                    try {
                        Get-ADComputer -Identity $workstationName -ErrorAction Stop | Out-Null
                        continue  # Already exists
                    }
                    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                        # Computer doesn't exist, continue
                    }
                    
                    $computerParams = @{
                        Name = $workstationName
                        SamAccountName = "$workstationName$"
                        Path = $ouPath
                        Description = "$category Workstation"
                        Enabled = $true
                    }
                    
                    New-ADComputer @computerParams
                    
                    $stats.WorkstationsCreated++
                }
                catch {
                    $stats.WorkstationsFailed++
                }
            }
            else {
                $stats.WorkstationsCreated++
            }
        }
        
        Write-Host "  Created $count workstations in $category" -ForegroundColor Green
    }

    Write-Host "`n==============================================================`n" -ForegroundColor Cyan
}

# ============================================================
# SUMMARY
# ============================================================
Write-Host "=============================================================="  -ForegroundColor Green
Write-Host "                    SUMMARY STATISTICS" -ForegroundColor Green
Write-Host "==============================================================`n" -ForegroundColor Green

if ($UserCount -gt 0) {
    Write-Host "USERS:" -ForegroundColor Cyan
    Write-Host "  Created: $($stats.UsersCreated)" -ForegroundColor $(if ($stats.UsersCreated -gt 0) { "Green" } else { "White" })
    Write-Host "  Failed:  $($stats.UsersFailed)" -ForegroundColor $(if ($stats.UsersFailed -gt 0) { "Red" } else { "White" })
}

if ($CreateServers) {
    Write-Host "`nSERVERS:" -ForegroundColor Cyan
    Write-Host "  Created: $($stats.ServersCreated)" -ForegroundColor $(if ($stats.ServersCreated -gt 0) { "Green" } else { "White" })
    Write-Host "  Failed:  $($stats.ServersFailed)" -ForegroundColor $(if ($stats.ServersFailed -gt 0) { "Red" } else { "White" })
}

if ($CreateWorkstations) {
    Write-Host "`nWORKSTATIONS:" -ForegroundColor Cyan
    Write-Host "  Created: $($stats.WorkstationsCreated)" -ForegroundColor $(if ($stats.WorkstationsCreated -gt 0) { "Green" } else { "White" })
    Write-Host "  Failed:  $($stats.WorkstationsFailed)" -ForegroundColor $(if ($stats.WorkstationsFailed -gt 0) { "Red" } else { "White" })
}

Write-Host "`nGROUP MEMBERSHIPS:" -ForegroundColor Cyan
Write-Host "  Added:   $($stats.MembershipsAdded)" -ForegroundColor $(if ($stats.MembershipsAdded -gt 0) { "Green" } else { "White" })
Write-Host "  Failed:  $($stats.MembershipsFailed)" -ForegroundColor $(if ($stats.MembershipsFailed -gt 0) { "Red" } else { "White" })

$totalCreated = $stats.UsersCreated + $stats.ServersCreated + $stats.WorkstationsCreated
$totalFailed = $stats.UsersFailed + $stats.ServersFailed + $stats.WorkstationsFailed

Write-Host "`nTOTAL:" -ForegroundColor Cyan
Write-Host "  Objects Created: $totalCreated" -ForegroundColor $(if ($totalCreated -gt 0) { "Green" } else { "White" })
Write-Host "  Objects Failed:  $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })

Write-Host "`n==============================================================`n" -ForegroundColor Green

if ($WhatIf) {
    Write-Host "NOTE: This was a WHATIF run - no changes were made" -ForegroundColor Yellow
}
else {
    Write-Host "Population complete!" -ForegroundColor Green
    Write-Host "The Automated-Lab-Changes script now has objects to work with`n" -ForegroundColor Green
}