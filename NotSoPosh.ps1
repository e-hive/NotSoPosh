<#
.SYNOPSIS
Customizes the PowerShell prompt to include optional enhancements.

.NOTES
- The script uses caching to optimize performance for both Azure subscription and Git branch lookups, 
  but latency during remote lookups should be considered.
#>

function prompt {
    # Load configuration from config file
    $configPath = Join-Path -Path (Split-Path $PSCommandPath) -ChildPath "notsoposh.config.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath | ConvertFrom-Json
            $script:__enableIcons = $config.enableIcons
            $script:__showNewLine = $config.showNewLine
            $script:__showMachineContext = $config.showMachineContext
            $script:__showUserContext = $config.showUserContext
            $script:__showAzSubscriptionContext = $config.showAzSubscriptionContext
            $script:__showBranchContext = $config.showBranchContext
        } catch {
            # Fallback to defaults if config is corrupted
            $script:__enableIcons = $true
            $script:__showNewLine = $false
            $script:__showMachineContext = $false
            $script:__showUserContext = $false
            $script:__showAzSubscriptionContext = $false
            $script:__showBranchContext = $false
        }
    } else {
        # Defaults if no config file exists
        $script:__enableIcons = $true
        $script:__showNewLine = $false
        $script:__showMachineContext = $false
        $script:__showUserContext = $false
        $script:__showAzSubscriptionContext = $false
        $script:__showBranchContext = $false
    }

    # Initialize Prompt - adds a new line to make history more readable
    $customPrompt = ""

    function Get-AzSubscriptionContext {
        # check if azure CLI is available
        if (-not (Get-Command "az" -ErrorAction SilentlyContinue)) {
            return ""
        }
        if (-not($script:__subscriptionId) -or $script:__subscriptionId -ne (az account show --query "id" --output tsv)) {
            try {
                $subscriptionId = az account show --query "id" --output tsv
                $subscriptionName = az account show --query "name" --output tsv
                $script:__subscriptionId = $subscriptionId
                $icon = if ($script:__enableIcons) { "☁️ " } else { "" }
                $script:__subscriptionName = "| $icon$subscriptionName "
                return $script:__subscriptionName
            } catch {
                return "Azure lookup failed"
            }
        } else {
            return $script:__subscriptionName
        }
        return ""
    }

    function Get-GitBranch {
        param (
            [string]$startPath = (Get-Location)
        )

        # check if git is available
        if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
            return ""
        }   

        if ($script:__gitRoot -and $startPath -like "$($script:__gitRoot)*") {
            return $script:__gitBranch
        }

        $script:__gitRoot = $null
        $script:__gitBranch = $null

        $currentPath = $startPath
        while ($currentPath -ne [System.IO.Path]::GetPathRoot($currentPath)) {
            $gitPath = Join-Path -Path $currentPath -ChildPath ".git"
            if (Test-Path $gitPath) {
                $headFile = Join-Path -Path $gitPath -ChildPath "HEAD"
                if (Test-Path $headFile) {
                    $headContent = Get-Content $headFile -TotalCount 1
                    if ($headContent -match "ref: refs/heads/(.+)") {
                        $script:__gitRoot = $currentPath
                        $icon = if ($script:__enableIcons) { "🌿 " } else { "" }
                        $script:__gitBranch = "| $icon$($matches[1]) "
                        return $script:__gitBranch
                    }
                }
            }
            $currentPath = [System.IO.Directory]::GetParent($currentPath).FullName
        }
        return ""
    }

    if ($script:__showNewLine -eq $true) {
        $customPrompt = "`nPS "
    } else {
        $customPrompt = "PS "
    }

    if ($script:__showMachineContext -eq $true) {
        $icon = if ($script:__enableIcons) { "🖥️ " } else { "" }
        $customPrompt += "| $icon$env:COMPUTERNAME "
    }

    if ($script:__showUserContext -eq $true) {
        $icon = if ($script:__enableIcons) { "👤 " } else { "" }
        $customPrompt += "| $icon$env:USERNAME "
    }

    if ($script:__showAzSubscriptionContext -eq $true) {
        $customPrompt += "$(Get-AzSubscriptionContext)"
    }

    if ($script:__showBranchContext -eq $true) {
        $customPrompt += "$(Get-GitBranch)"
    }

    return "$($customPrompt)| $(Get-Location)> "
}