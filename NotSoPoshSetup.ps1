<#
.SYNOPSIS
NotSoPosh Setup - Configures a custom PowerShell prompt with optional enhancements.

.NOTES
- The script deploys the custom prompt script to a local folder named ".pwshprompt".
- It updates the PowerShell PROFILE to include the custom prompt configuration.
- The PowerShell session is restarted at the end of the script to apply the changes.
- To remove customisations rerun this script.
#>

. ".\NotSoPoshHelper.ps1"

$showNewLine = $false
$showUserContext = $false
$showMachineContext = $false
$showSubscriptionContext = $false
$showBranchContext = $false

# Try to load existing configuration from local setup directory
$localConfigPath = ".\notsoposh.config.json"

if (Test-Path $localConfigPath) {
    try {
        Write-Host "NOTSOPOSH SETUP: Loading existing configuration from setup directory..."
        $existingConfig = Get-Content $localConfigPath | ConvertFrom-Json
        $showNewLine = $existingConfig.showNewLine
        $showUserContext = $existingConfig.showUserContext
        $showMachineContext = $existingConfig.showMachineContext
        $showSubscriptionContext = $existingConfig.showAzSubscriptionContext
        $showBranchContext = $existingConfig.showBranchContext
        Write-Host "NOTSOPOSH SETUP: Previous settings loaded"
    } catch {
        Write-Host "NOTSOPOSH SETUP: Could not load existing config, using defaults" -ForegroundColor Yellow
    }
}

# Build prompt Options array
$options = @()
$options += "Include New Line between prompts"
$options += "Include Machine Name Context in your prompt"
$options += "Include Current User Context in your prompt"

# Check for Azure CLI
$azCliAvailable = Get-Command "az" -ErrorAction SilentlyContinue
if ($azCliAvailable) {
    $options += "Include Azure Subscription Context in your prompt (adds latency)"
} else {
    Write-Host "NOTSOPOSH SETUP: To unlock Azure Subscription Context you need to install Azure CLI first." -ForegroundColor Yellow
}

# Check for Git
$gitAvailable = Get-Command "git" -ErrorAction SilentlyContinue
if ($gitAvailable) {
    $options += "Include Current Branch Context in your prompt"
} else {
    Write-Host "NOTSOPOSH SETUP: To unlock Current Branch Context you need to install Git first." -ForegroundColor Yellow
}

# Show menu
# Build default selected options based on current configuration
$defaultSelected = @()
$optionIndex = 0

if ($showNewLine) { $defaultSelected += $optionIndex }
$optionIndex++

if ($showMachineContext) { $defaultSelected += $optionIndex }
$optionIndex++

if ($showUserContext) { $defaultSelected += $optionIndex }
$optionIndex++

if ($azCliAvailable -and $showSubscriptionContext) { $defaultSelected += $optionIndex }
if ($azCliAvailable) { $optionIndex++ }

if ($gitAvailable -and $showBranchContext) { $defaultSelected += $optionIndex }

$selectedOptions = Show-MenuWrapper -Title "Configure NotSoPosh Options" -Options $options -DefaultSelected $defaultSelected

# Process selected options - reset all to false first, then set selected ones to true
$showNewLine = $false
$showMachineContext = $false
$showUserContext = $false
$showSubscriptionContext = $false
$showBranchContext = $false

$optionIndex = 0
if($selectedOptions -contains $optionIndex) {
    Write-Host "NOTSOPOSH SETUP: Including New Line between prompts"
    $showNewLine = $true
} else {
    Write-Host "NOTSOPOSH SETUP: Excluding New Line between prompts"
}
$optionIndex++

if ($selectedOptions -contains $optionIndex) {
    Write-Host "NOTSOPOSH SETUP: Including Machine Name Context in your prompt"
    $showMachineContext = $true
} else {
    Write-Host "NOTSOPOSH SETUP: Excluding Machine Name Context from your prompt"
}
$optionIndex++

if ($selectedOptions -contains $optionIndex) {
    Write-Host "NOTSOPOSH SETUP: Including Current User Context in your prompt"
    $showUserContext = $true
} else {
    Write-Host "NOTSOPOSH SETUP: Excluding Current User Context from your prompt"
}
$optionIndex++

if ($azCliAvailable) {
    if ($selectedOptions -contains $optionIndex) {
        Write-Host "NOTSOPOSH SETUP: Including Azure Subscription Context in your prompt"
        $showSubscriptionContext = $true
    } else {
        Write-Host "NOTSOPOSH SETUP: Excluding Azure Subscription Context from your prompt"
    }
    $optionIndex++
}

if ($gitAvailable) {
    if ($selectedOptions -contains $optionIndex) {
        Write-Host "NOTSOPOSH SETUP: Including Current Branch Context in your prompt"
        $showBranchContext = $true
    } else {
        Write-Host "NOTSOPOSH SETUP: Excluding Current Branch Context from your prompt"
    }
}

# Create configuration object
$config = @{
    showNewLine = $showNewLine
    showMachineContext = $showMachineContext
    showUserContext = $showUserContext
    showAzSubscriptionContext = $showSubscriptionContext
    showBranchContext = $showBranchContext
}

# Save configuration to local file for persistence between runs
$scriptFile = "NotSoPosh.ps1"
$configFile = "notsoposh.config.json"
$config | ConvertTo-Json | Set-Content -Path $configFile
Write-Host "NOTSOPOSH SETUP: Configuration stored"

Write-Host "`nNOTSOPOSH SETUP: Deploying files" -ForegroundColor DarkCyan
$deployedFilePath = Deploy-LocalScript -SourceFilePaths @($scriptFile, $configFile) -LocalScriptFolderName ".notsoposh"

# Find the deployed script path for the profile override
$targetScript = $deployedFilePath | Where-Object { $_ -like "*NotSoPosh.ps1" }

Write-Host "NOTSOPOSH SETUP: Files deployed successfully"

$promptOverride = @"
#=========================================
# NotSoPosh Custom Prompt
#=========================================
if (Test-Path -Path $targetScript) {
    . $targetScript
}
"@

Write-Host "`nNOTSOPOSH SETUP: Updating Profile" -ForegroundColor DarkCyan
Update-Profile -ContentQuery "# NotSoPosh Custom Prompt" -Content $promptOverride

# Restart the script session to pick up the changes
Write-Host "`nNOTSOPOSH SETUP: Opening new PowerShell session`n`n" -ForegroundColor DarkCyan
Start-Process "pwsh" -WindowStyle Normal