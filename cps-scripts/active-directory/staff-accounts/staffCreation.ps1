# Created by   : I. Jared
# Date Created : 4/26/2023
# Purpose      : Automating staff account creation and updating fields if they exist.

# Change this first variable should the export file need to move for whatever reason.
#$MAS_EXPORT_FILE = "MAS_EXPORT.csv"
$MAS_EXPORT_FILE = "MAS_EXPORT_TESTING.csv"

# Alternatively, execute these commands as administrator with a scheduled task : 
# powershell ".\staffCreation.ps1" > staffCreation.log
#$LOGGING_FILE = "[PATH]\STAFF_CREATION.log"

#! All of these sites should conform to the two-character name standard soon,
#! just waiting for the greenlight form Michael to change the container names in AD.
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
# as superintendents that may have multiple roles or for people who would complain enough if
# their account switched to their legal name from whatever name they use now (i.e. Brad -> Kevin by 
# the script's default control flow.). 

# 80314 -> Max Myers (district super)
# 80367 -> Brad Tackett (CF-NO)
$employeeIDsToExclude = @("80314", "80367", "12345")

Write-Host "            ################################################`
            #    COWETA PUBLIC SCHOOLS STAFF ACCOUNT       #`
            #                  GENERATOR                   #`
            #                                              #`
            ################################################"

Write-Host "`nDATE: $(Get-Date -UFormat "%m/%d/%Y %R")`n"

# TODO: Make Python script to prep Michael's MAS export file 
# Main logic for staff account creation.
foreach ($user in $usersToCreate) {

    # Placeholders to remove annoying special characters; only removing ' and - from names for now.
    $firstHolder = $user.firstName
    $lastHolder = $user.lastName

    # Aligning values from CSV columns to variables..
    $EmployeeID = $user.employeeID

    # Stripping any apostrophes / dashes / whitespace from names.
    $FirstName = $($firstHolder -replace "'","" -replace "-","" -replace " ","")
    $LastName = $($lastHolder -replace "'","" -replace "-","" -replace " ","")

    #$Username = $user.username 
    $Username = "$FirstName.$LastName"

    $Password = $user.password
    $EmailAddress = $user.emailAddress
    $EmployeeType = $user.employeeType
    $JobTitle = $user.jobTitle
    $PrimaryLocation = $user.primaryLocation
    $Company = $user.company

    # TODO: Import phone numbers somehow.
    #$PhoneExtension = $user.phoneNumber

    # Checks for duplicate users, using the employeeID field. If they already exist, update fields.
    if ((Get-ADUser -F "employeeID -eq '$EmployeeID'" -Properties * | Select-Object -ExpandProperty EmployeeID)) {

        # Checks if the employeeID is currently in the exclusion array.
        if ($EmployeeID -in $employeeIDsToExclude) {
            Write-Host "`nEmployee $FirstName $LastName ($EmployeeID) is in the excluded accounts array, skipping field updates...`n"
        }

        # Updating all pertinent fields.
        else {

            $userObj = Get-ADUser -F "employeeID -eq '$EmployeeID'" -Properties * | Select-Object -ExpandProperty SamAccountName
            $distName = Get-ADUser -F "employeeID -eq '$EmployeeID'" -Properties * | Select-Object -ExpandProperty DistinguishedName

            # Doing this for updating fields of people with duplicate names.
            # It's stupid but this is the easiest way I can think of, fix it if there's
            # a better way (or if I figure something out). Compares if last 3 chars of the username
            # equals first initial/last initial/employeeID (since it's appended to duplicate name users).
            $truncatedNameHolder = $($userObj -replace '^.*(?=.{3}$)').ToString()
            $appendedStringForDuplicates = $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $EmployeeID.Substring($EmployeeID.get_Length() - 1)

            #Write-Host "$truncatedNameHolder $appendedStringForDuplicates"

            if ($truncatedNameHolder -eq $appendedStringForDuplicates) {
                Write-Host "$userObj was initially created with a duplicate name, keeping former naming convention.."
                $Username = $Username + $appendedStringForDuplicates

                $userOUtoAssign = $locationToOU[$PrimaryLocation]

                $LastName = $LastName + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $EmployeeID.Substring($EmployeeID.get_Length() - 1)

                Set-ADUser `
                -Identity $userObj `
                -GivenName $FirstName `
                -Surname $LastName `
                -UserPrincipalName $("$Username@cowetaps.com") `
                -SamAccountName $Username `
                -Description $EmployeeType `
                -DisplayName $("$FirstName $LastName") `
                -Department $PrimaryLocation `
                -Title $JobTitle `
                -EmailAddress $("$Username@cowetaps.com") `
                -Company $Company 

                Move-ADObject -Identity $distName -TargetPath $userOUtoAssign
                Rename-ADObject -Identity $distName -NewName $("$FirstName $LastName")

                # FIXME: Format better with backticks.
                Write-Host "UPDATING ACCOUNT : $Username`n`First Name: $FirstName`n`Last Name: $LastName`n`Temp Password: $Password`n`Email: $EmailAddress`n`Employee Type: $EmployeeType`n`Job Title: $JobTitle`n`Primary Location: $PrimaryLocation`n`Company: $Company`n`Employee ID: $EmployeeID`n"
                Write-Host "Moving $userObj to : $userOUtoAssign`n"

            }

            else {
                $userOUtoAssign = $locationToOU[$PrimaryLocation]

                Set-ADUser `
                -Identity $userObj `
                -GivenName $FirstName `
                -Surname $LastName `
                -UserPrincipalName $("$Username@cowetaps.com") `
                -SamAccountName $Username `
                -Description $EmployeeType `
                -DisplayName $("$FirstName $LastName") `
                -Department $PrimaryLocation `
                -Title $JobTitle `
                -EmailAddress $EmailAddress `
                -Company $Company 

                Move-ADObject -Identity $distName -TargetPath $userOUtoAssign
                Rename-ADObject -Identity $distName -NewName $("$FirstName $LastName")

                # TODO : Fix backticks not working on this correctly for some reason.
                Write-Host "UPDATING ACCOUNT : $Username`n`First Name: $FirstName`n`Last Name: $LastName`n`Temp Password: $Password`n`Email: $EmailAddress`n`Employee Type: $EmployeeType`n`Job Title: $JobTitle`n`Primary Location: $PrimaryLocation`n`Company: $Company`n`Employee ID: $EmployeeID`n"
                Write-Host "Moving $userObj to : $userOUtoAssign`n"
            }
        }
    }

    # Main magic that happens.
    else {
        $userOUtoAssign = $locationToOU[$PrimaryLocation]
        
        # My workaround for the rare instance of a duplicate employee name.
        # [ first initial ][ last initial ][ last digit of employee ID ] convention.
        # I went with this method to deal with duplicate names because 2 random digits would be too inconsistent and unreliable to deal with.
        # This should (in a perfect world) handle up to 10 staff with a duplicate name, as 0-9 will be the last digit of the ID number.
        if ((Get-ADUser -F "SamAccountName -eq '$Username'" -Properties * | Select-Object -ExpandProperty SamAccountName)) {
            Write-Host "Username combination $Username already exists, appending initials and last employee ID digit for UPN/SAM: `n"
            $Username = $Username + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $EmployeeID.Substring($EmployeeID.get_Length() - 1)
            Write-Host "New Username: $Username`n"
            $LastName = $LastName + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $EmployeeID.Substring($EmployeeID.get_Length() - 1)
        }

        # For the time being, Description is being hijacked by : EMPLOYEE TYPE
        New-ADUser `
            -Name $("$FirstName $LastName") `
            -GivenName $FirstName `
            -Path $userOUtoAssign `
            -Surname $LastName `
            -UserPrincipalName $("$Username@cowetaps.com") `
            -SamAccountName $Username `
            -EmployeeID $EmployeeID `
            -Description $EmployeeType `
            -DisplayName $("$FirstName $LastName") `
			-Department $PrimaryLocation `
            -Title $JobTitle `
            -EmailAddress $EmailAddress `
            -Company $Company `
            -AccountPassword $(ConvertTo-SecureString $Password -AsPlainText -Force) `
            -ChangePasswordAtLogon $True `
            -Enabled $True

        # FIXME: Format this better with backticks.
        Write-Host "CREATING ACCOUNT : $Username`n`First Name: $FirstName`n`Last Name: $LastName`n`Password: $Password`n`Email: $EmailAddress`n`Employee Type: $EmployeeType`n`Job Title: $JobTitle`n`Primary Location: $PrimaryLocation`n`Company: $Company`n`Employee ID: $EmployeeID`n"
        Write-Host "$userOUtoAssign is the OU for this account.`n`n"
    }
}
