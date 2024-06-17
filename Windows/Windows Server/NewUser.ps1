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
function Check-OUExists {
    param (
        [string]$OU
    )
    try {
        $OUObject = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'"
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

# Get compulsory user details interactively
$DisplayName = Get-CompulsoryInput "Enter Display Name:"
$Username = Get-CompulsoryInput "Enter Username (SamAccountName):"

# Check if the username already exists
if (UserExists -Username $Username) {
    Write-Host "The user '$Username' already exists in the domain. Exiting setup."
    exit
}

$Password = Get-CompulsoryInput "Enter Password:"

# Get optional user details interactively
$Description = Get-OptionalInput "Enter Description (Optional):"
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
