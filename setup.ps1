function Setup {
    while ($true) {
        Write-Host "`nWelcome to the setup script!"
        Write-Host "Please select your OS flavor:"

        # Get the list of directories and filter out 'DEB' and hidden directories
        $osDirectories = Get-ChildItem -Directory -Path . | Where-Object { $_.Name -ne 'DEB' -and $_.Name -notmatch '^\.' } | Select-Object -ExpandProperty Name

        # Debugging: Print out the directories
        Write-Host "Debug: OS Directories List - $($osDirectories -join ', ')"

        $osDirectories += "Exit"

        # Display the directories
        for ($idx = 0; $idx -lt $osDirectories.Count; $idx++) {
            Write-Host "$($idx + 1). $($osDirectories[$idx])"
        }

        # Get user choice
        $choice = Read-Host "Enter your choice (1-$($osDirectories.Count))"

        if ($choice -match '^\d+$') {
            $choice = [int]$choice
            if ($choice -ge 1 -and $choice -le $osDirectories.Count) {
                if ($choice -eq $osDirectories.Count) {
                    Write-Host "Exiting..."
                    break
                } else {
                    $osFlavor = $osDirectories[$choice - 1]
                    List-Tools -osFlavor $osFlavor
                }
            } else {
                Write-Host "Invalid choice! Please enter a valid option."
            }
        } else {
            Write-Host "Invalid input. Please enter a number."
        }
    }
}

function List-Tools {
    param (
        [string]$osFlavor
    )

    while ($true) {
        $osPath = Join-Path -Path (Get-Location) -ChildPath $osFlavor
        try {
            $toolScripts = Get-ChildItem -Path $osPath -Filter *.ps1 | Select-Object -ExpandProperty BaseName
            if ($toolScripts.Count -eq 0) {
                Write-Host "No tools found for the selected OS."
                return
            }

            Write-Host "`nAvailable tools for ${osFlavor}:"
            for ($idx = 0; $idx -lt $toolScripts.Count; $idx++) {
                Write-Host "$($idx + 1). $($toolScripts[$idx])"
            }
            Write-Host "$($toolScripts.Count + 1). Back"
            Write-Host "$($toolScripts.Count + 2). Exit"

            $toolChoice = Read-Host "Enter the number of the tool you want to run"

            if ($toolChoice -match '^\d+$') {
                $toolChoice = [int]$toolChoice - 1
                if ($toolChoice -ge 0 -and $toolChoice -lt $toolScripts.Count) {
                    $selectedTool = "$($toolScripts[$toolChoice]).ps1"
                    Run-ToolScript -osPath $osPath -toolScript $selectedTool
                } elseif ($toolChoice -eq $toolScripts.Count) {
                    return # Back to OS flavor selection
                } elseif ($toolChoice -eq $toolScripts.Count + 1) {
                    Write-Host "Exiting..."
                    exit
                } else {
                    Write-Host "Invalid choice!"
                }
            } else {
                Write-Host "Invalid input. Please enter a number."
            }
        } catch {
            Write-Host "No tools directory found for the selected OS."
            return
        }
    }
}

function Run-ToolScript {
    param (
        [string]$osPath,
        [string]$toolScript
    )

    $scriptPath = Join-Path -Path $osPath -ChildPath $toolScript
    try {
        Write-Host "Running script: $scriptPath"
        & $scriptPath
    } catch {
        Write-Host "An error occurred while running the script: $_"
    }
}

# Start the setup process
Setup
