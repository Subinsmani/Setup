[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

# Function to get optional user input with a default value
function Get-OptionalInput {
    param (
        [string]$Prompt,
        [string]$DefaultValue = ""
    )
    if ($DefaultValue -ne "") {
        $Prompt = "$Prompt [$DefaultValue]"
    }
    $Input = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($Input)) {
        $Input = $DefaultValue
    }
    return $Input
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
function Check-OUExists {
    param (
        [string]$OU
    )
    try {
        $OUObject = Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to display a list of choices and get a valid selection
function Get-Choice {
    param (
        [string[]]$Choices,
        [string]$Prompt
    )
    for ($i = 0; $i -lt $Choices.Length; $i++) {
        $choiceIndex = $i
        $choiceValue = $Choices[$i]
        Write-Host ("{0}: {1}" -f $choiceIndex, $choiceValue)
    }
    $ChoiceIndex = Read-Host $Prompt
    while (-not ($ChoiceIndex -as [int]) -or ($ChoiceIndex -lt 0) -or ($ChoiceIndex -ge $Choices.Length)) {
        Write-Host "Invalid choice. Please try again."
        $ChoiceIndex = Read-Host $Prompt
    }
    return $Choices[$ChoiceIndex]
}

# Function to search for the Disabled Users OU dynamically
function Search-DisabledOU {
    $ous = Get-ADOrganizationalUnit -Filter "Name -like '*Disabled*Users*'" -Properties DistinguishedName
    return $ous
}

# Function to disable a user and update their description
function DisableUser {
    param (
        [string]$Username,
        [string]$Description
    )
    try {
        Disable-ADAccount -Identity $Username
        Set-ADUser -Identity $Username -Description $Description
        $CurrentOU = (Get-ADUser -Identity $Username).DistinguishedName
        Write-Host "User '$Username' has been disabled and kept in the same OU."
        Write-Host "Current OU: $CurrentOU"
    } catch {
        Write-Host "An error occurred while disabling the user: $_"
    }
}

# Function to move a user to a new OU, disable them, and update their description
function MoveAndDisableUser {
    param (
        [string]$Username,
        [string]$TargetOU,
        [string]$Description
    )
    try {
        Disable-ADAccount -Identity $Username
        Move-ADObject -Identity (Get-ADUser -Identity $Username).DistinguishedName -TargetPath $TargetOU
        Set-ADUser -Identity $Username -Description $Description
        Write-Host "User '$Username' has been disabled and moved to '$TargetOU'."
    } catch {
        Write-Host "An error occurred while disabling or moving the user: $_"
    }
}

# Function to generate a random password using DinoPass API
function Get-DinoPassPassword {
    $url = "https://www.dinopass.com/password/strong"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response
    } catch {
        Write-Host "An error occurred while fetching the password from DinoPass API: $_"
        return $null
    }
}

# Function to validate the generated password
function Validate-Password {
    param (
        [string]$Password
    )
    if ($Password.Length -ge 10 -and $Password -match '[a-z]' -and $Password -match '[A-Z]' -and $Password -match '[\W_]') {
        return $true
    }
    return $false
}

# Function to display the disclaimer
function Show-Disclaimer {
    Write-Host "##############################################"
    Write-Host "#                                            #"
    Write-Host "#  Script Name: Active Directory Management  #"
    Write-Host "#  Author: Subins Mani                       #"
    Write-Host "#  Email: subins.mani@thelogoscorp.com       #"
    Write-Host "#                                            #"
    Write-Host "#  © 2024 Subins Mani. All rights reserved.  #"
    Write-Host "#                                            #"
    Write-Host "##############################################"
    Write-Host ""
}

# Main menu function
function Main-Menu {
    Show-Disclaimer
    Write-Host "Select an option:"
    Write-Host "(1) Add User"
    Write-Host "(2) Reset User Password"
    Write-Host "(3) Delete/Disable User"
    Write-Host "(4) Exit"
    $Selection = Read-Host "Enter your choice (1-4):"

    switch ($Selection) {
        1 {
            Add-User
        }
        2 {
            Reset-UserPassword
        }
        3 {
            DeleteOrDisable-User
        }
        4 {
            Write-Host "Exiting..."
            exit
        }
        default {
            Write-Host "Invalid selection. Please try again."
            Main-Menu
        }
    }
}

# Function to add a new user
function Add-User {
    $DisplayName = Get-CompulsoryInput "Enter Display Name:"
    $Username = Get-CompulsoryInput "Enter Username (SamAccountName):"

    # Check if the username already exists
    if (UserExists -Username $Username) {
        Write-Host "The user '$Username' already exists in the domain. Exiting setup."
        exit
    }

    $Password = Get-CompulsoryInput "Enter Password:"

    # Get the current date
    $Date = Get-Date -Format "yyyy-MM-dd"
    $DefaultDescription = "User Created on $Date - "

    # Get optional user details interactively
    $AdditionalDescription = Read-Host -Prompt "Enter Description [$DefaultDescription]"
    $Description = "$DefaultDescription$AdditionalDescription"
    $Email = Get-OptionalInput "Enter Email (Optional):"
    $Phone = Get-OptionalInput "Enter Phone (Optional):"

    # Ask if the user wants to copy from a template user
    $UseTemplateResponse = Get-CompulsoryInput "Do you want to copy attributes from a template user? (Yes/No)"
    if ($UseTemplateResponse -match "^(Y|Yes)$") {
        $TemplateUser = Get-CompulsoryInput "Enter Template Username:"
        # Get the template user details
        $Template = Get-ADUser -Identity $TemplateUser -Properties *
        # Determine the OU for the new user
        $TemplateOU = ($Template.DistinguishedName -split ',')[1..($Template.DistinguishedName.Length)] -join ','

        Write-Host "The template user is found in the following OU: $TemplateOU"
        $OUResponse = Read-Host "Do you want to save the new user to the same OU? (Yes/No)"

        if ($OUResponse -match "^(Y|Yes)$") {
            $OU = $TemplateOU
        } else {
            do {
                $OU = Get-CompulsoryInput "Enter the OU for the new user:"
                if (-not (Check-OUExists $OU)) {
                    Write-Host "OU not available. Please re-enter."
                }
            } until (Check-OUExists $OU)
        }
    } else {
        do {
            $OU = Get-CompulsoryInput "Enter the OU for the new user:"
            if (-not (Check-OUExists $OU)) {
                Write-Host "OU not available. Please re-enter."
            }
        } until (Check-OUExists $OU)
    }

    # Split DisplayName into FirstName and SecondName
    $NameParts = $DisplayName -split ' ', 2
    if ($NameParts.Length -eq 2) {
        $FirstName = $NameParts[0]
        $SecondName = $NameParts[1]
    } else {
        $FirstName = $NameParts[0]
        $SecondName = ""
    }

    # List all available UPN suffixes or use the root domain if none are available
    $UPNSuffixes = (Get-ADForest).UPNSuffixes

    if ($UPNSuffixes.Count -eq 0) {
        Write-Host "No UPN suffixes found in the current domain. Defaulting to root domain UPN suffix."
        $UPNSuffix = (Get-ADForest).RootDomain
    } else {
        Write-Host "Available UPN suffixes:"
        $UPNSuffix = Get-Choice -Choices $UPNSuffixes -Prompt "Select a UPN suffix for the new user from the above list (enter the number):"
    }

    # Initialize the attributes to be copied from the template user, if they are not null
    $OtherAttributes = @{}
    if ($TemplateUser -and $Template) {
        if ($Template.Title) { $OtherAttributes['title'] = $Template.Title }
        if ($Template.Department) { $OtherAttributes['department'] = $Template.Department }
        if ($Template.Company) { $OtherAttributes['company'] = $Template.Company }
        if ($Template.Office) { $OtherAttributes['physicalDeliveryOfficeName'] = $Template.Office }
    }

    # Add email and phone to the attributes if provided
    if ($Email) { $OtherAttributes['mail'] = $Email }
    if ($Phone) { $OtherAttributes['mobile'] = $Phone }

    # Create the new user by copying all attributes from the template user
    New-ADUser `
        -Name $DisplayName `
        -GivenName $FirstName `
        -Surname $SecondName `
        -SamAccountName $Username `
        -UserPrincipalName "$Username@$UPNSuffix" `
        -Path $OU `
        -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
        -Enabled $true `
        -Description $Description `
        -OtherAttributes $OtherAttributes `
        -PassThru

    # Set additional attributes for the user if template user was used
    if ($TemplateUser -and $Template) {
        Set-ADUser -Identity $Username `
            -DisplayName $DisplayName `
            -Title $Template.Title `
            -Department $Template.Department `
            -Company $Template.Company `
            -Office $Template.Office `
            -AccountExpirationDate $Template.AccountExpirationDate `
            -PasswordNeverExpires $Template.PasswordNeverExpires

        # Add user to the same groups as the template user
        foreach ($group in $Template.MemberOf) {
            Add-ADGroupMember -Identity $group -Members $Username
        }
    }

    # Debug: Verify UserPrincipalName and account settings
    $CreatedUser = Get-ADUser -Identity $Username -Properties UserPrincipalName, AccountExpirationDate, PasswordNeverExpires
    Write-Host "Created UserPrincipalName: $($CreatedUser.UserPrincipalName)"
    Write-Host "PasswordNeverExpires: $($CreatedUser.PasswordNeverExpires)"
    Write-Host "AccountExpirationDate: $($CreatedUser.AccountExpirationDate)"
}

# Function to reset a user password
function Reset-UserPassword {
    $Username = Get-CompulsoryInput "Enter Username (SamAccountName):"

    # Check if the username exists
    if (-not (UserExists -Username $Username)) {
        Write-Host "The user '$Username' does not exist in the domain. Exiting setup."
        exit
    }

    # Ask if the user wants to generate a random password or input manually
    $PasswordOption = Get-CompulsoryInput "Do you want to generate a random password? (Yes/No)"
    if ($PasswordOption -match "^(Y|Yes)$") {
        do {
            do {
                $NewPassword = Get-DinoPassPassword
            } until (Validate-Password -Password $NewPassword)
            
            Write-Host "Generated Password: $NewPassword"
            Write-Host "Do you want to use this password?"
            Write-Host "1. Use this password"
            Write-Host "2. Regenerate again"
            $UsePassword = Read-Host "Enter your choice (1 or 2):"
        } until ($UsePassword -eq '1')
    } else {
        $NewPassword = Get-CompulsoryInput "Enter New Password:"
        $ConfirmPassword = Get-CompulsoryInput "Confirm New Password:"

        # Ensure the passwords match
        while ($NewPassword -ne $ConfirmPassword) {
            Write-Host "Passwords do not match. Please try again."
            $NewPassword = Get-CompulsoryInput "Enter New Password:"
            $ConfirmPassword = Get-CompulsoryInput "Confirm New Password:"
        }
    }

    # Convert the new password to a secure string
    $SecurePassword = ConvertTo-SecureString $NewPassword -AsPlainText -Force

    # Reset the user's password and unlock the account
    try {
        Set-ADAccountPassword -Identity $Username -NewPassword $SecurePassword -Reset
        Unlock-ADAccount -Identity $Username
        Write-Host "Password for user '$Username' has been successfully reset."
    } catch {
        Write-Host "An error occurred while resetting the password or unlocking the account: $_"
    }

    Write-Host "Password reset process completed."
}

# Function to delete or disable a user
function DeleteOrDisable-User {
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

        # Get the current date
        $Date = Get-Date -Format "yyyy-MM-dd"
        $DefaultDescription = "User Disabled on $Date - "

        # Get optional user details interactively
        $AdditionalDescription = Read-Host -Prompt "Enter Description [$DefaultDescription]"
        $Description = "$DefaultDescription$AdditionalDescription"

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
                    if (Check-OUExists -OU $NewOU) {
                        MoveAndDisableUser -Username $Username -TargetOU $NewOU -Description $Description
                    } else {
                        Write-Host "The specified OU '$NewOU' does not exist. Please check the path and try again."
                    }
                } elseif ($SelectedOUIndex -match '^\d+$' -and [int]$SelectedOUIndex -ge 1 -and [int]$SelectedOUIndex -le $disabledOUs.Count) {
                    $TargetOU = $disabledOUs[[int]$SelectedOUIndex - 1].DistinguishedName
                    MoveAndDisableUser -Username $Username -TargetOU $TargetOU -Description $Description
                } else {
                    Write-Host "Invalid selection."
                    DisableUser -Username $Username -Description $Description
                }
            } else {
                Write-Host "No Disabled Users OU found."
                DisableUser -Username $Username -Description $Description
            }
        } else {
            DisableUser -Username $Username -Description $Description
        }
    } else {
        Write-Host "Invalid option. Exiting setup."
    }
}

# Start the script by displaying the main menu
Main-Menu
