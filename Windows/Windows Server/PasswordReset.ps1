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

# Get compulsory user details interactively
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
        $UsePassword = Get-CompulsoryInput "Do you want to use this password? Enter '1' for Use it or '2' to generate again:"
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
