# Import the Active Directory module
Import-Module ActiveDirectory

# Function to get user input with validation
function Get-CompulsoryInput {
    param (
        [string]$Prompt
    )
    $Input = Read-Host $Prompt
    while ([string]::IsNullOrWhiteSpace($Input)) {
        Write-Host "Input cannot be empty. Please try again."
        $Input = Read-Host $Prompt
    }
    return $Input
}

# Function to get optional user input
function Get-OptionalInput {
    param (
        [string]$Prompt
    )
    return Read-Host $Prompt
}

# Function to check if a user exists
function UserExists {
    param (
        [string]$Username
    )
    try {
        $User = Get-ADUser -Identity $Username -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to check if an OU exists
function OUExists {
    param (
        [string]$OUPath
    )
    try {
        $OU = Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to search for the Disabled Users OU dynamically
function Search-DisabledOU {
    $ous = Get-ADOrganizationalUnit -Filter 'Name -like "*Disabled*Users*"' -Properties DistinguishedName
    return $ous
}

# Function to disable a user and display their current OU
function DisableUser {
    param (
        [string]$Username
    )
    try {
        Disable-ADAccount -Identity $Username
        $CurrentOU = (Get-ADUser -Identity $Username).DistinguishedName
        Write-Host "User '$Username' has been disabled and kept in the same OU."
        Write-Host "Current OU: $CurrentOU"
    } catch {
        Write-Host "An error occurred while disabling the user: $_"
    }
}

# Function to move a user to a new OU and disable them
function MoveAndDisableUser {
    param (
        [string]$Username,
        [string]$TargetOU
    )
    try {
        Disable-ADAccount -Identity $Username
        Move-ADObject -Identity (Get-ADUser -Identity $Username).DistinguishedName -TargetPath $TargetOU
        Write-Host "User '$Username' has been disabled and moved to '$TargetOU'."
    } catch {
        Write-Host "An error occurred while disabling or moving the user: $_"
    }
}

# Ask the user for the operation
Write-Host "Do you want to:"
Write-Host "(1) Permanently delete a user account"
Write-Host "(2) Disable a user account"
$Operation = Read-Host "Enter the number of the operation you want to perform:"

if ($Operation -eq "1") {
    $Username = Get-CompulsoryInput "Enter Username (SamAccountName) to delete:"
    if (-not (UserExists -Username $Username)) {
        Write-Host "The user '$Username' does not exist. Exiting setup."
        exit
    }

    $ConfirmDelete = Read-Host "Are you sure you want to permanently delete the user '$Username'? (Yes/No)"
    if ($ConfirmDelete -match "^(Y|Yes)$") {
        try {
            Remove-ADUser -Identity $Username -Confirm:$false
            Write-Host "User '$Username' has been permanently deleted."
        } catch {
            Write-Host "An error occurred while deleting the user: $_"
        }
    } else {
        Write-Host "User deletion cancelled."
    }
} elseif ($Operation -eq "2") {
    $Username = Get-CompulsoryInput "Enter Username (SamAccountName) to disable:"
    if (-not (UserExists -Username $Username)) {
        Write-Host "The user '$Username' does not exist. Exiting setup."
        exit
    }

    $Description = Get-OptionalInput "Enter a description for the disablement (optional):"
    
    $MoveToDisabledOU = Get-CompulsoryInput "Do you want to move the user to a Disabled Users OU? (Yes/No)"
    if ($MoveToDisabledOU -match "^(Y|Yes)$") {
        $disabledOUs = Search-DisabledOU

        if ($disabledOUs.Count -gt 0) {
            Write-Host "Found the following Disabled Users OUs:"
            for ($i = 0; $i -lt $disabledOUs.Count; $i++) {
                Write-Host "$($i + 1): $($disabledOUs[$i].DistinguishedName)"
            }
            
            $SelectedOUIndex = Read-Host "Enter the number of the OU you want to move the user to (or press Enter to skip):"
            
            if ([string]::IsNullOrWhiteSpace($SelectedOUIndex)) {
                $NewOU = Get-CompulsoryInput "Enter the target OU path:"
                if (OUExists -OUPath $NewOU) {
                    MoveAndDisableUser -Username $Username -TargetOU $NewOU
                } else {
                    Write-Host "The specified OU '$NewOU' does not exist. Please check the path and try again."
                }
            } elseif ($SelectedOUIndex -match '^\d+$' -and [int]$SelectedOUIndex -ge 1 -and [int]$SelectedOUIndex -le $disabledOUs.Count) {
                $TargetOU = $disabledOUs[[int]$SelectedOUIndex - 1].DistinguishedName
                MoveAndDisableUser -Username $Username -TargetOU $TargetOU
            } else {
                Write-Host "Invalid selection."
                DisableUser -Username $Username
            }
        } else {
            Write-Host "No Disabled Users OU found."
            DisableUser -Username $Username
        }
    } else {
        DisableUser -Username $Username
    }
} else {
    Write-Host "Invalid option. Exiting setup."
}
