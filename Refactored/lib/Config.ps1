function Get-ScriptConfiguration {
    <#
    .SYNOPSIS
    Loads configuration from JSON files
    
    .PARAMETER SettingsPath
    Path to settings.json
    
    .PARAMETER ActionsPath
    Path to actions.json
    #>
    param(
        [string]$SettingsPath = './config/settings.json',
        [string]$ActionsPath = './config/actions.json'
    )
    
    $config = @{}
    
    # Load settings
    if (-not (Test-Path $SettingsPath)) {
        Write-Error "Settings file not found: $SettingsPath"
        exit 1
    }
    
    try {
        $config.settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        Write-Verbose "Loaded settings from $SettingsPath"
    } catch {
        Write-Error "Failed to parse settings.json: $_"
        exit 1
    }
    
    # Load actions
    if (-not (Test-Path $ActionsPath)) {
        Write-Error "Actions file not found: $ActionsPath"
        exit 1
    }
    
    try {
        $actionData = Get-Content $ActionsPath -Raw | ConvertFrom-Json
        $config.actions = $actionData.actions
        Write-Verbose "Loaded $($config.actions.Count) actions from $ActionsPath"
    } catch {
        Write-Error "Failed to parse actions.json: $_"
        exit 1
    }
    
    return $config
}

function Get-ActionsByRole {
    <#
    .SYNOPSIS
    Get actions filtered by role
    #>
    param(
        [object[]]$Actions,
        [string]$Role
    )
    
    return $Actions | Where-Object { $_.role -eq $Role }
}

function Get-WeightedActions {
    <#
    .SYNOPSIS
    Build weighted list of actions for random selection
    #>
    param(
        [object[]]$Actions,
        [string]$Role
    )
    
    $weighted = @()
    $roleActions = Get-ActionsByRole -Actions $Actions -Role $Role | Where-Object { $_.enabled -eq $true }
    
    foreach ($action in $roleActions) {
        for ($i = 1; $i -le $action.weight; $i++) {
            $weighted += $action
        }
    }
    
    return $weighted | Sort-Object { Get-Random }
}

function Get-RoleDistribution {
    <#
    .SYNOPSIS
    Get weighted role distribution for normal mode
    #>
    param(
        [object[]]$Actions
    )
    
    # Define role weights
    $roleWeights = @{
        'helpdesk' = 5
        'service' = 4
        'desktop' = 3
        'server' = 2
        'domainadmin' = 1
    }
    
    $weighted = @()
    foreach ($role in $roleWeights.Keys) {
        $weight = $roleWeights[$role]
        for ($i = 1; $i -le $weight; $i++) {
            $weighted += $role
        }
    }
    
    return $weighted
}
