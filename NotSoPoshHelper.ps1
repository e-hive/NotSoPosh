function Deploy-LocalScript {
    param (
        [string[]]$SourceFilePaths,    # Array of file paths to be copied
        [string]$LocalScriptFolderName
    )

    # Get the local user's directory
    $userDirectory = [System.Environment]::GetFolderPath("UserProfile")

    # Define the full path to the .notsoposh folder
    $notsoposhFolderPath = Join-Path -Path $userDirectory -ChildPath $LocalScriptFolderName

    # Check if the .notsoposh folder exists, create it if it doesn't
    if (-not (Test-Path $notsoposhFolderPath)) {
        New-Item -Path $notsoposhFolderPath -ItemType Directory
        Write-Host "DEPLOY: Created folder: $notsoposhFolderPath"
    } else {
        Write-Host "DEPLOY: Folder already exists: $notsoposhFolderPath"
    }

    $deployedFiles = @()

    # Copy each file to the folder
    foreach ($sourceFilePath in $SourceFilePaths) {
        if (Test-Path $sourceFilePath) {
            $destinationPath = Join-Path -Path $profileFolderPath -ChildPath (Split-Path -Path $sourceFilePath -Leaf)
            Copy-Item -Path $sourceFilePath -Destination $destinationPath -Force
            Write-Host "DEPLOY: Copied file to: $destinationPath"
            $deployedFiles += $destinationPath
        } else {
            Write-Host "DEPLOY: File not found: $sourceFilePath" -ForegroundColor Yellow
        }
    }

    return $deployedFiles
}

function Update-Profile {
    param (
        # The content to append to the profile file
        [Parameter(Mandatory = $true)]
        [string]$Content,

        # A string to check for before appending content to the profile file
        [Parameter(Mandatory = $true)]
        [string]$ContentQuery
    )

    try {
        $pwshProfilePath = 'PowerShell\Microsoft.PowerShell_profile.ps1'

        Write-Host "UPDATE-PROFILE: Checking Pwsh PROFILE..."
        Write-Host "UPDATE-PROFILE: $PROFILE"

        if ($PROFILE -notlike "*$pwshProfilePath*") {
            Write-Host "UPDATE-PROFILE: Unexpected PROFILE path. Expected: $pwshProfilePath"
            Write-Host "UPDATE-PROFILE: You may be running an unsupported version of PowerShell Core."
            Write-Host "UPDATE-PROFILE: Exiting setup."
            exit
        }

        # Get an absolute PROFILE path
        if ([System.IO.Path]::IsPathRooted($PROFILE)) {
            $absoluteProfilePath = $PROFILE
        } else {
            $absoluteProfilePath = Join-Path $env:USERPROFILE -ChildPath $pwshProfilePath
        }

        # Create PROFILE if missing
        if (-not (Test-Path -Path $absoluteProfilePath)) {
            Write-Host "UPDATE-PROFILE: Pwsh PROFILE does not exist. Creating..."
            New-Item -Path $absoluteProfilePath -ItemType File -Force | Out-Null
        }

        # Get PROFILE contents
        $profileContent = Get-Content -Path $absoluteProfilePath

        # If our module content isn't already added
        if (-not ($profileContent | Select-String -Pattern $ContentQuery)){
            # Get approval to proceed
            $confirmation = Read-Host "`nUPDATE-PROFILE: Pwsh PROFILE is not empty. Do you want to modify it? (yes/no)"
            if ($confirmation -ne "yes") {
                Write-Host "UPDATE-PROFILE: Exiting setup."
                exit
            }

            if (-not ([string]::IsNullOrWhiteSpace($profileContent))) {
                # Backup current profile if its not empty
                if (Test-Path -Path $absoluteProfilePath) {
                    $timestamp = (Get-Date -Format "yyyyMMddHHmmss")
                    $backupPath = "$absoluteProfilePath.$timestamp.bak"
                    Copy-Item -Path $absoluteProfilePath -Destination $backupPath -Force
                    Write-Host "UPDATE-PROFILE: Backup created: $backupPath"
                }
            }

            # If we get to this point the file can be updated
            Write-Host "`nUPDATE-PROFILE: Modifying PROFILE..."
            Add-Content -Path $absoluteProfilePath -Value $Content
            Write-Host "UPDATE-PROFILE: Updated with Content."
        } else {
            Write-Host "UPDATE-PROFILE: PROFILE Already contains $($ContentQuery). Skipping..."
        }

    } catch {
        Write-Host "UPDATE-PROFILE: Update failed" -ForegroundColor Red
        $err = $_
        Write-Host " - Error Message: $($err.Exception.Message)"
        Write-Host " - Error Line Number: $($err.InvocationInfo.ScriptLineNumber)"
        Write-Host " - Error Position: $($err.InvocationInfo.PositionMessage)"
        Write-Host " - Error Script Name: $($err.InvocationInfo.ScriptName)"
        exit
    }
}

function Assert-RuntimeRequirements {
    # Check if running PowerShell 7+
    if ($Host.Version.Major -lt 7) {
        Write-Host "NOTSOPOSH SETUP: This script requires PowerShell 7 or higher." -ForegroundColor Red
        Write-Host "NOTSOPOSH SETUP: Current version: $($Host.Version)" -ForegroundColor Red
        Write-Host "NOTSOPOSH SETUP: Exiting setup."
        exit
    }

    # Check if script is running in the correct execution context
    if ($PSCmdlet -and $MyInvocation.InvocationName -eq '.') {
        Write-Host "NOTSOPOSH SETUP: This script must not be dot-sourced. Please run it directly as a script file." -ForegroundColor Red
        Write-Host "NOTSOPOSH SETUP: Exiting setup."
        exit
    }

    # Check for elevated permissions
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "NOTSOPOSH SETUP: This script requires elevated permissions (Run as Administrator)." -ForegroundColor Red
        Write-Host "NOTSOPOSH SETUP: Exiting setup."
        exit
    }

    # Check if this is a windows system
    if (-not $IsWindows) {
        Write-Host "NOTSOPOSH SETUP: This script is designed to run on Windows systems only." -ForegroundColor Red
        Write-Host "NOTSOPOSH SETUP: Exiting setup."
        exit
    }

    Write-Host "NOTSOPOSH SETUP: Environment checks passed. Proceeding with setup..." -ForegroundColor DarkGreen
}

function Show-MenuWrapper {
    param (
        [string]$Title = "Select Options",
        [array]$Options,
        [array]$DefaultSelected = @()
    )
    
    $selectedIndices = @()
    if ($DefaultSelected.Count -gt 0) {
        $selectedIndices = $DefaultSelected
    }
    
    $currentIndex = 0
    $maxIndex = $Options.Count - 1
    
    function Show-Menu {
        Clear-Host
        Write-Host "`n$Title" -ForegroundColor DarkCyan
        Write-Host ("=====================================================================")
        Write-Host ""
        
        for ($i = 0; $i -lt $Options.Count; $i++) {
            $prefix = if ($i -eq $currentIndex) { ">" } else { " " }
            $checkbox = if ($selectedIndices -contains $i) { "[X]" } else { "[ ]" }
            $color = if ($i -eq $currentIndex) { "Yellow" } else { "White" }
            
            Write-Host "$prefix $checkbox $($Options[$i])" -ForegroundColor $color
        }
        
        Write-Host ""
        Write-Host ("---------------------------------------------------------------------")
        Write-Host "Use ↑/↓ to navigate, SPACE to toggle, ENTER to confirm, ESC to cancel" -ForegroundColor Gray
    }
    
    do {
        Show-Menu
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $currentIndex = if ($currentIndex -eq 0) { $maxIndex } else { $currentIndex - 1 }
            }
            40 { # Down arrow
                $currentIndex = if ($currentIndex -eq $maxIndex) { 0 } else { $currentIndex + 1 }
            }
            32 { # Spacebar
                if ($selectedIndices -contains $currentIndex) {
                    $selectedIndices = $selectedIndices | Where-Object { $_ -ne $currentIndex }
                } else {
                    $selectedIndices += $currentIndex
                }
            }
            13 { # Enter
                Clear-Host
                return $selectedIndices
            }
            27 { # Escape
                Clear-Host
                exit
            }
        }
    } while ($true)
}