function Setup {
    while ($true) {
        Write-Host "`nWelcome to the setup script!"
        Write-Host "Please select your OS flavor:"

        # Get the list of directories and filter out 'DEB', 'Downloads', and hidden directories
        $osDirectories = @(Get-ChildItem -Directory -Path . | Where-Object { $_.Name -ne 'DEB' -and $_.Name -ne 'Downloads' -and $_.Name -notmatch '^\.' } | Select-Object -ExpandProperty Name)

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
                    if ($osFlavor -eq "Windows") {
                        List-WindowsSubfolders -osFlavor $osFlavor
                    } else {
                        List-Subfolders -osFlavor $osFlavor
                    }
                }
            } else {
                Write-Host "Invalid choice! Please enter a valid option."
            }
        } else {
            Write-Host "Invalid input. Please enter a number."
        }
    }
}

function List-WindowsSubfolders {
    param (
        [string]$osFlavor
    )

    while ($true) {
        $osPath = Join-Path -Path (Get-Location) -ChildPath $osFlavor
        try {
            $subFolders = @(Get-ChildItem -Directory -Path $osPath | Select-Object -ExpandProperty Name)

            if ($subFolders.Count -eq 0) {
                Write-Host "No subfolders found for the selected OS."
                return
            }

            Write-Host "`nAvailable Windows versions:"
            for ($idx = 0; $idx -lt $subFolders.Count; $idx++) {
                Write-Host "$($idx + 1). $($subFolders[$idx])"
            }
            Write-Host "$($subFolders.Count + 1). Back"
            Write-Host "$($subFolders.Count + 2). Exit"

            $folderChoice = Read-Host "Enter the number of the Windows version you want to explore"

            if ($folderChoice -match '^\d+$') {
                $folderChoice = [int]$folderChoice - 1
                if ($folderChoice -ge 0 -and $folderChoice -lt $subFolders.Count) {
                    $selectedFolder = $subFolders[$folderChoice]
                    List-Tools -osPath (Join-Path -Path $osPath -ChildPath $selectedFolder)
                } elseif ($folderChoice -eq $subFolders.Count) {
                    return # Back to OS flavor selection
                } elseif ($folderChoice -eq $subFolders.Count + 1) {
                    Write-Host "Exiting..."
                    exit
                } else {
                    Write-Host "Invalid choice!"
                }
            } else {
                Write-Host "Invalid input. Please enter a number."
            }
        } catch {
            Write-Host "No subfolders found for the selected OS."
            return
        }
    }
}

function List-Subfolders {
    param (
        [string]$osFlavor
    )

    while ($true) {
        $osPath = Join-Path -Path (Get-Location) -ChildPath $osFlavor
        try {
            $subFolders = @(Get-ChildItem -Directory -Path $osPath | Select-Object -ExpandProperty Name)

            if ($subFolders.Count -eq 0) {
                Write-Host "No subfolders found for the selected OS."
                return
            }

            Write-Host "`nAvailable subfolders for ${osFlavor}:"
            for ($idx = 0; $idx -lt $subFolders.Count; $idx++) {
                Write-Host "$($idx + 1). $($subFolders[$idx])"
            }
            Write-Host "$($subFolders.Count + 1). Back"
            Write-Host "$($subFolders.Count + 2). Exit"

            $folderChoice = Read-Host "Enter the number of the subfolder you want to explore"

            if ($folderChoice -match '^\d+$') {
                $folderChoice = [int]$folderChoice - 1
                if ($folderChoice -ge 0 -and $folderChoice -lt $subFolders.Count) {
                    $selectedFolder = $subFolders[$folderChoice]
                    List-Tools -osPath (Join-Path -Path $osPath -ChildPath $selectedFolder)
                } elseif ($folderChoice -eq $subFolders.Count) {
                    return # Back to OS flavor selection
                } elseif ($folderChoice -eq $subFolders.Count + 1) {
                    Write-Host "Exiting..."
                    exit
                } else {
                    Write-Host "Invalid choice!"
                }
            } else {
                Write-Host "Invalid input. Please enter a number."
            }
        } catch {
            Write-Host "No subfolders found for the selected OS."
            return
        }
    }
}

function List-Tools {
    param (
        [string]$osPath
    )

    while ($true) {
        try {
            $toolScripts = @(Get-ChildItem -Path $osPath -Filter *.ps1 | Select-Object -ExpandProperty BaseName)
            if ($toolScripts.Count -eq 0) {
                Write-Host "No tools found in the selected subfolder."
                return
            }

            Write-Host "`nAvailable tools for Windows Server:"
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
                    Run-ToolScript -scriptPath (Join-Path -Path $osPath -ChildPath $selectedTool)
                } elseif ($toolChoice -eq $toolScripts.Count) {
                    return # Back to subfolder selection
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
            Write-Host "No tools found in the selected subfolder."
            return
        }
    }
}

function Run-ToolScript {
    param (
        [string]$scriptPath
    )

    try {
        & $scriptPath
    } catch {
        Write-Host "An error occurred while running the script: $_"
    }
}

# Start the setup process
Setup
