# Test harness for Invoke-AutomatedLabChanges
# Dot-sources the script to load all functions and variables, without running the main loop.
# Uncomment the action(s) you want to test and run this script.

. "$PSScriptRoot\Invoke-AutomatedLabChanges.ps1" -TestOnly

# ---------------------------------------------------------------------------
# Invoke-ServiceAccountAction
# ---------------------------------------------------------------------------
#Invoke-ServiceAccountAction -serviceAccount "svc-callmanager"
#Invoke-ServiceAccountAction -serviceAccount "svc-offboarding"
#Invoke-ServiceAccountAction -serviceAccount "svc-onboarding"
#Invoke-ServiceAccountAction -serviceAccount "svc-pam"

# ---------------------------------------------------------------------------
# Invoke-DesktopAction
# ---------------------------------------------------------------------------
#Invoke-DesktopAction -desktopAction "computerDelete"
#Invoke-DesktopAction -desktopAction "computerDisable"
#Invoke-DesktopAction -desktopAction "computerNew"
#Invoke-DesktopAction -desktopAction "userNew"
#Invoke-DesktopAction -desktopAction "userNewDesEncryption"
#Invoke-DesktopAction -desktopAction "userNewReversibleEncryption"
#Invoke-DesktopAction -desktopAction "userNewPasswordNotRequired"
#Invoke-DesktopAction -desktopAction "userDisable"
#Invoke-DesktopAction -desktopAction "updateDepartmentGroup"

# ---------------------------------------------------------------------------
# Invoke-DomainAdminAction
# ---------------------------------------------------------------------------
#Invoke-DomainAdminAction -domainAdminAction "dnsRecordAdd"
#Invoke-DomainAdminAction -domainAdminAction "dnsRecordDelete"
#Invoke-DomainAdminAction -domainAdminAction "gpoLink"
#Invoke-DomainAdminAction -domainAdminAction "gpoNew"
#Invoke-DomainAdminAction -domainAdminAction "gpoLinkRemove"
#Invoke-DomainAdminAction -domainAdminAction "newSubnet"
#Invoke-DomainAdminAction -domainAdminAction "setServerSPN"
Invoke-DomainAdminAction -domainAdminAction "gpoRegistryValue"

# ---------------------------------------------------------------------------
# Invoke-HelpdeskAction
# ---------------------------------------------------------------------------
#Invoke-HelpdeskAction -helpdeskAction "userDisable"
#Invoke-HelpdeskAction -helpdeskAction "userEnable"
#Invoke-HelpdeskAction -helpdeskAction "computerDisable"
#Invoke-HelpdeskAction -helpdeskAction "computerEnable"
#Invoke-HelpdeskAction -helpdeskAction "passwordAbnormalRefresh"
#Invoke-HelpdeskAction -helpdeskAction "passwordAtNextLogon"
#Invoke-HelpdeskAction -helpdeskAction "passwordReset"
#Invoke-HelpdeskAction -helpdeskAction "passwordResetInDescription"
#Invoke-HelpdeskAction -helpdeskAction "updateConfidentialGroup"
#Invoke-HelpdeskAction -helpdeskAction "userUpdateDescription"

# ---------------------------------------------------------------------------
# Invoke-ServerAction
# ---------------------------------------------------------------------------
#Invoke-ServerAction -serverAction "computerDelete"
#Invoke-ServerAction -serverAction "computerDisable"
#Invoke-ServerAction -serverAction "computerEnable"
#Invoke-ServerAction -serverAction "computerNew"
#Invoke-ServerAction -serverAction "groupNewMember"
