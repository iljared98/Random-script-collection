# Created by   : I. Jared
# Date Created : 4/26/2023
# Purpose      : Automating staff account creation and updating fields if they exist.

# Change this first variable should the export file need to move for whatever reason.
$MAS_EXPORT_FILE = "MAS_EXPORT.csv"
# TODO: Robust logging for account creation.
# Right now nothing is even being written to this file, maybe add the print statements later along with
# timestamps???
$LOGGING_FILE = "[PATH]\STAFF_CREATION.log" 

# These function similarly to Jooel's AddUser.ini OU mappings
# per site. The intention with District mapping to NULL is to ensure
# District employees are being mapped to OUs by their job titles
# by Michael's request.

$locationToOU = @{
    "Band" = "OU=Users,OU=Band,OU=STAFF,DC=cowetaps,DC=com"
    "CE" = "OU=Users,OU=CE,OU=STAFF,DC=cowetaps,DC=com"
    "SS" = "OU=Users,OU=SS,OU=STAFF,DC=cowetaps,DC=com"
    "NW" = "OU=Users,OU=NW,OU=STAFF,DC=cowetaps,DC=com"
    "MIGC" = "OU=Users,OU=MIGC,OU=STAFF,DC=cowetaps,DC=com"
    "HIGC" = "OU=Users,OU=HIGC,OU=STAFF,DC=cowetaps,DC=com"
    "JH" = "OU=Users,OU=JH,OU=STAFF,DC=cowetaps,DC=com"
    "IHS" = "OU=Users,OU=IHS,OU=STAFF,DC=cowetaps,DC=com"
    "HS" = "OU=Users,OU=HS,OU=STAFF,DC=cowetaps,DC=com"
    "ESC" = "OU=Users,OU=ESC,OU=STAFF,DC=cowetaps,DC=com"
    "Transportation" = "OU=Users,OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "Maintenance" = "OU=Users,OU=Maintenance,OU=STAFF,DC=cowetaps,DC=com"
    "Child Nutrition" = "OU=Users,OU=Child Nutrition,OU=STAFF,DC=cowetaps,DC=com"
    "District" = "OU=Users,OU=District,OU=STAFF,DC=cowetaps,DC=com"
    "Test" = "OU=Users,OU=test_staff,OU=STAFF,DC=cowetaps,DC=com"
}

# Do not touch this.
$usersToCreate = Import-CSV $MAS_EXPORT_FILE

# This is an array of users to exclude from the update logic branch. Mostly includes VIPs such
# as superintendents that may have multiple roles (i.e. Max Myers as district super / bus driver).
# Please document who these employeeIDs belong to, as the employeeID is the main comparison field
# for account duplication / field updates. 
# 80314 -> Max Myers (district super)
# Number -> User (role) etc...
$employeeIDsToExclude = "80314", "1234567890"

# Main logic for staff account creation.
foreach ($user in $usersToCreate) {

    # Aligning values from CSV columns to variables..
    $EmployeeID = $user.employeeID
    $FirstName = $user.firstName
    $LastName = $user.lastName
    $Username = $user.username 
    $Password = $user.password
    $EmailAddress = $user.emailAddress
    $EmployeeType = $user.employeeType
    $JobTitle = $user.jobTitle
    $PrimaryLocation = $user.primaryLocation
    # Only add this back into both the CSV and the script if Michael requests it. Otherwise keep commented out.
    #$randomDigitColumn = $user.randomDigit # that one 2-3 digit column Michael put in the CSV. Forgot what it's for.
    $Company = $user.company

    # Checks for duplicate users, using the employeeID field. If they already exist, update fields.
    if (Get-ADUser -F {EmployeeID -eq $EmployeeID}) {

        # Checks if the employeeID is currently in the exclusion array.
        if ($EmployeeID -in $employeeIDsToExclude) {
            Write-Host "`nEmployee $Username is in the excluded accounts array, not updating attribute fields...`n"
        }

        # Updating fields that would be pertinent. Might leave out the name change / email fields
        # just in case that would cause errors on our cloud tenant side of things. HOWEVER, with how
        # often people get remarried / divorced and it changes their name, may as well have it here just
        # in case.
        else {
            Write-Host "`nEmployee ID exists and not excluded, updating user fields:`n"
            Set-ADUser `
            -Name $("$FirstName $LastName") `
            -GivenName $FirstName `
            -Path $userOUtoAssign `
            -Surname $LastName `
            -UserPrincipalName $("$Username@cowetaps.com") `
            -DisplayName $("$FirstName $LastName") `
			-Department $PrimaryLocation `
            -Title $JobTitle `
            -EmailAddress $EmailAddress 


        }
    }

    # Main magic that happens.
    else {

        # TODO: Add logic branch here to fix duplicate names.
        # Probably use UPNs since we didn't make SAMs for those mass generated accounts.
        if (Get-ADUser ) {
            Write-Host "Duplicate name $Username exists but no matching employeeID found, making new user with digit appended to name."
            
        }
        $userOUtoAssign = $locationToOU[$PrimaryLocation]
        # Currently Description maps to the variable $EmployeeType (certified/support). Change if we add a custom extended field later.
        
        # For the time being, Description is being hijacked by : EMPLOYEE TYPE, or for students, [information that would be useful].
        New-ADUser `
            -Name $("$FirstName $LastName") `
            -GivenName $FirstName `
            -Path $userOUtoAssign `
            -Surname $LastName `
            -UserPrincipalName $("$Username@cowetaps.com") `
            -EmployeeID $EmployeeID `
            -DisplayName $("$FirstName $LastName") `
			-Department $PrimaryLocation `
            -Title $JobTitle `
            -EmailAddress $EmailAddress `
            -Company $Company `
            -AccountPassword $(ConvertTo-SecureString $Password -AsPlainText -Force) `
            -ChangePasswordAtLogon $True `
            -Enabled $True

        Write-Host "CREATING ACCOUNT : $Username. `nFirstName: $FirstName`nLastName: $LastName`nPass: $Password`nEmail: $EmailAddress`nEmployeeType: $EmployeeType`nJobTitle: $JobTitle`nPrimaryLocation: $PrimaryLocation`nCompany: $Company`nEmpID: $EmployeeID`n"
        Write-Host "$userOUtoAssign is the OU for this account.`n`n"
        
    }
}

# Put this block back on lines 34-58 IF we need it, otherwise just leave it here.

# Also, create distinctions for generic role such as SECRETARY in case it is repeated at multiple sites (i.e. a maintenance or 
# transportation secretary).
# ADD DISTRICT TITLES / RESPECTIVE OUs TO THIS DICTIONARY AS NECESSARY. OTHER SITES DO NOT NEED THIS.
# This is due to the definition of "District" employees being very broad in MAS exports.
<# $titleToOU = @{
    "ASST GROUNDS MANAGER" = "OU=District,OU=STAFF,DC=cowetaps,DC=com"
    "DISTRICT NURSE" = "OU=District,OU=STAFF,DC=cowetaps,DC=com"
    "Nurse" = "OU=District,OU=STAFF,DC=cowetaps,DC=com" # Set as is to match what is in the CSV. Why we can't just make this DISTRICT NURSE is beyond me.
    "LAY COACH" = "OU=District,OU=STAFF,DC=cowetaps,DC=com"
    "SECRETARY" = "" # TODO: There is a definition for this both as a Maintenance and District employee. Need to figure something out.
    "DIRECTOR CHILD NUTRITION" = "OU=Child Nutrition,OU=STAFF,DC=cowetaps,DC=com"
    "DIRECTOR MAINTENANCE" = "OU=Maintenance,OU=STAFF,DC=cowetaps,DC=com"
    "MAINTENANCE" = "OU=Maintenance,OU=STAFF,DC=cowetaps,DC=com"

    # Why can't we just have straightforward job titles...
    "BUS AND SHUTTLE DRIVER-FT" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "BUS ASSISTANT" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "BUS DRIVER" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "BUS DRIVER AND SHUTTLE" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "BUS DRIVER/DELIVERY DRIVER" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "DIRECTOR TRANSPORTATION" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "SHUTTLE DRIVER"= "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
    "HEAD MECHANIC" = "OU=Transportation,OU=STAFF,DC=cowetaps,DC=com"
} #>
