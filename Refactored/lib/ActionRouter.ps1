function Invoke-Action {
    <#
    .SYNOPSIS
    Route and execute an action based on role and name
    
    .PARAMETER Role
    Role performing the action (desktop, helpdesk, server, service, domainadmin)
    
    .PARAMETER Action
    Action name to execute
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Role,
        
        [Parameter(Mandatory=$true)]
        [string]$Action
    )
    
    $functionName = "Invoke-$role`Action"
    
    if (-not (Get-Command -Name $functionName -ErrorAction SilentlyContinue)) {
        Write-Error "Action function not found: $functionName"
        return
    }
    
    try {
        & $functionName -$($role)Action $Action
    } catch {
        Write-Error "Failed to execute action: $Role :: $Action - $_"
    }
}

function Get-ActionInfo {
    <#
    .SYNOPSIS
    Get metadata for an action
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Actions,
        
        [Parameter(Mandatory=$true)]
        [string]$Role,
        
        [Parameter(Mandatory=$true)]
        [string]$ActionName
    )
    
    return $Actions | Where-Object { 
        $_.role -eq $Role -and $_.name -eq $ActionName 
    } | Select-Object -First 1
}

function Test-ActionExists {
    <#
    .SYNOPSIS
    Check if an action exists and is enabled
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Actions,
        
        [Parameter(Mandatory=$true)]
        [string]$Role,
        
        [Parameter(Mandatory=$true)]
        [string]$ActionName
    )
    
    $action = Get-ActionInfo -Actions $Actions -Role $Role -ActionName $ActionName
    return ($null -ne $action) -and ($action.enabled -eq $true)
}
