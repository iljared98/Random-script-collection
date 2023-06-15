# Created by   : I. Jared
# Date Created : 5/8/2023
# Purpose      : Automating the creation of student accounts and grade promotions in AD.

# To dump the output of this script to a log, run the command below.
# powershell ".\studentCreation.ps1" > studentCreation.log

#! Do not change this file unless absolutely necessary.
#$PS_EXPORT_FILE = "AZAD_Students.csv"
$PS_EXPORT_FILE = "AZAD_Students_test.csv"


$DISABLED_OU = "OU=Disabled_Students,OU=STUDENTS,DC=cowetaps,DC=com"

# Dictionary of school codes.
# CA = HS Academy students 
$schoolCodes = @{
    "705" = "OU=HS,OU=STUDENTS,DC=cowetaps,DC=com"
    "710" = "OU=IH,OU=STUDENTS,DC=cowetaps,DC=com"
    "715" = "OU=CA,OU=STUDENTS,DC=cowetaps,DC=com" 
    "610" = "OU=JH,OU=STUDENTS,DC=cowetaps,DC=com"
    "210" = "OU=HI,OU=STUDENTS,DC=cowetaps,DC=com"
    "205" = "OU=MI,OU=STUDENTS,DC=cowetaps,DC=com"
    "105" = "OU=CE,OU=STUDENTS,DC=cowetaps,DC=com"
    "110" = "OU=NW,OU=STUDENTS,DC=cowetaps,DC=com"
    "115" = "OU=SS,OU=STUDENTS,DC=cowetaps,DC=com"
    "999999" = "Graduated Students" 
    "TestSite" = "OU=test_student,OU=STUDENTS,DC=cowetaps,DC=com"
}

# Dictionary of grade strings.
# 0 for K, rest should be obvious.
$schoolGrades = @{
    "0" = "OU=Users,OU=K,"
    "1" = "OU=Users,OU=1ST,"
    "2" = "OU=Users,OU=2ND,"
    "3" = "OU=Users,OU=3RD,"
    "4" = "OU=Users,OU=4TH,"
    "5" = "OU=Users,OU=5TH,"
    "6" = "OU=Users,OU=6TH,"
    "7" = "OU=Users,OU=7TH,"
    "8" = "OU=Users,OU=8TH,"
    "9" = "OU=Users,OU=9TH,"
    "10" = "OU=Users,OU=10TH,"
    "11" = "OU=Users,OU=11TH,"
    "12" = "OU=Users,OU=12TH,"
}

$studentGroups = @{
    "705" = "CN=HS_Students,OU=HS,OU=STUDENTS,DC=cowetaps,DC=com"
    "710" = "CN=IH_Students,OU=IH,OU=STUDENTS,DC=cowetaps,DC=com"
    "715" = "CN=CA_Students,OU=CA,OU=STUDENTS,DC=cowetaps,DC=com" 
    "610" = "CN=JH_Students,OU=JH,OU=STUDENTS,DC=cowetaps,DC=com"
    "210" = "CN=HI_Students,OU=HI,OU=STUDENTS,DC=cowetaps,DC=com"
    "205" = "CN=MI_Students,OU=MI,OU=STUDENTS,DC=cowetaps,DC=com"
    "105" = "CN=CE_Students,OU=CE,OU=STUDENTS,DC=cowetaps,DC=com"
    "110" = "CN=NW_Students,OU=NW,OU=STUDENTS,DC=cowetaps,DC=com"
    "115" = "CN=SS_Students,OU=SS,OU=STUDENTS,DC=cowetaps,DC=com"
    "TestSite" = "CN=TEST_Students,OU=test_student,OU=STUDENTS,DC=cowetaps,DC=com"
}



Write-Host "            ################################################`
            #    COWETA PUBLIC SCHOOLS STUDENT ACCOUNT     #`
            #                  GENERATOR                   #`
            #                                              #`
            ################################################"

# For logging / debugging purposes.
Write-Host "`nDATE: $(Get-Date -UFormat "%m/%d/%Y %R")`n"

try {
$usersToCreate = Import-CSV $PS_EXPORT_FILE

foreach ($user in $usersToCreate) {

    # Aligning values from CSV columns to variables..
    $studentID = $user.studentNumber

    # Placeholders to remove annoying special characters; removing apostrophes, hyphens, and whitespace.
    $firstHolder = $user.firstName
    $lastHolder = $user.lastName

    $FirstName = $($firstHolder -replace "'","" -replace "-","" -replace " ","")
    $LastName = $($lastHolder -replace "'","" -replace "-","" -replace " ","")

    $studentGrade = $schoolGrades[$user.gradeLevel]
    $siteName = $schoolCodes[$user.schoolID] 

    $Username = "$FirstName.$LastName"

    # New student password convention. I had to add the exclamation point since Azure AD
    # complained about not having a special character for the passwords.
    #! NOTE: THE INITIALS ARE CAPITALIZED
    $Password = "!" + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID
    $Company = "Coweta Public Schools"

    # Checks for duplicate users, using the employeeID field. If they already exist, update fields.
    if ((Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty EmployeeID)) {

        # Updating fields that would be pertinent. 

        Write-Host "Student account for $FirstName $LastName ($studentID) already exists, updating fields in case of site changes..."

        $userObj = Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty SamAccountName
        $distName = Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName

        # Used to see if an account has a duped name already, if it does and a name change is needed, it keeps the naming convention.
        $truncatedNameHolder = $($userObj -replace '^.*(?=.{3}$)').ToString()
        $appendedStringForDuplicates = $firstHolder.Substring(0, 1) + $lastHolder.Substring(0, 1) + $studentID.Substring($studentID.get_Length() - 1)

        if ($truncatedNameHolder -eq $appendedStringForDuplicates) {
            # TODO: LENGTH CHECK FOR NAME

            Write-Host "`nChecking length of updated username..."

            if ($Username.get_Length() -gt 20) {
                Write-Host "Username is too long, truncating extra names to start..."
                $FirstName = $FirstName -replace '([A-Z][a-z]*)[A-Z][a-z]*', '$1'
                $LastName = $LastName -replace '([A-Z][a-z]*)[A-Z][a-z]*', '$1'
                $Username = "$FirstName.$LastName"
                if ($Username.get_Length() -gt 17) {
                    $Username = $Username.Substring(0, [Math]::Min($Username.Length, 17))
                    Write-Host "`nUsername was still too long, forcing name length to 17 characters...`nNEW NAME: $Username`n"
                }
                else {
                    Write-Host "`nUsername successfully shortened...`nNEW NAME: $Username`n"
                }
            }

            Write-Host "$userObj was initially created with a duplicate name, keeping former naming convention.."
            $Username = $Username + $appendedStringForDuplicates
            
            $userOUtoAssign = "$studentGrade$siteName"
            $userGroupToAssign = $studentGroups[$user.schoolID]
            
            try {
                Set-ADUser `
                -Identity $userObj `
                -GivenName $FirstName `
                -Surname $LastName `
                -UserPrincipalName $("$Username@cowetaps.com") `
                -SamAccountName $Username `
                -DisplayName $("$FirstName $LastName") `
                -Department $siteName.Substring(3, 2) `
                -EmailAddress $("$FirstName.$LastName@cowetaps.org") `
            }

            catch {
                write-Host "Something went wrong when updating fields for : $FirstName $LastName ($studentID)`nSkipping field updates for this user's account..."
            }
                
            try {
                Move-ADObject -Identity $distName -TargetPath $userOUtoAssign
                Write-Host "Moving $userObj to : $userOUtoAssign`n"
            }

            catch {
                Write-Host "Something went wrong when moving $userObj, skipping OU update!"
            }

            try {
                $currentGroup = Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty MemberOf
                Remove-ADGroupMember -Identity $currentGroup -Members $(Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName) -Confirm:$false
                Add-ADGroupMember -Identity $userGroupToAssign -Members $(Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName)
                Write-Host "Successfully updated group membership for: $Username"
            }

            catch {
                Write-Host "Group join didn't work, skipping!"
            }
                
            }

            else {
                $userOUtoAssign = "$studentGrade$siteName"
                $userGroupToAssign = $studentGroups[$user.schoolID]

                Write-Host "`nChecking length of updated username..."

                if ($Username.get_Length() -gt 20) {
                    Write-Host "Username is too long, truncating extra names to start..."
                    $FirstName = $FirstName -replace '([A-Z][a-z]*)[A-Z][a-z]*', '$1'
                    $LastName = $LastName -replace '([A-Z][a-z]*)[A-Z][a-z]*', '$1'
                    $Username = "$FirstName.$LastName"
                    if ($Username.get_Length() -gt 17) {
                        $Username = $Username.Substring(0, [Math]::Min($Username.Length, 17))
                        Write-Host "`nUsername was still too long, forcing name length to 17 characters...`nNEW NAME: $Username`n"
                        }
                    else {
                        Write-Host "`nUsername successfully shortened...`nNEW NAME: $Username`n"
                        }
                }

                try {
                    Set-ADUser `
                    -Identity $userObj `
                    -GivenName $FirstName `
                    -Surname $LastName `
                    -UserPrincipalName $("$Username@cowetaps.com") `
                    -SamAccountName $Username `
                    -DisplayName $("$FirstName $LastName") `
                    -Department $siteName.Substring(3, 2) `
                    -Title "Student" `
                    -EmailAddress $("$FirstName.$LastName@cowetaps.org") `
                }

                catch {
                    write-Host "Something went wrong when updating fields for : $FirstName $LastName ($studentID)`nSkipping field updates for this user's account..."
                }

                try {
                    Move-ADObject -Identity $distName -TargetPath $userOUtoAssign
                    Write-Host "Moving $userObj to : $userOUtoAssign`n"
                }

                catch {
                    Write-Host "Something went wrong when moving $userObj, skipping OU update!"
                }

                try {
                    $currentGroup = Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty MemberOf
                    Remove-ADGroupMember -Identity $currentGroup -Members $(Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName) -Confirm:$false
                    Add-ADGroupMember -Identity $userGroupToAssign -Members $(Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName)
                    Write-Host "Successfully updated group membership for: $Username"
                }

                catch {
                    Write-Host "Group join didn't work, skipping!"
                }
            }
    }

    # Create account if studentID doesn't exist in AD.
    else {

        # In case an export has bad data, ensures that we don't get accounts from invalid sites / grades.
        if ($schoolCodes.Values -notcontains $siteName -or $schoolGrades.Values -notcontains $studentGrade) {
            Write-Host "`n$FirstName $LastName ($studentID) has an invalid grade level or school code. Skipping creation of this account..."
        }

        # Same as above, this handles students are are newly enrolled but have not been filled out by registrars yet. Brand new students will all
        # have a lunch ID of 0 by default.
        elseif ($studentID -eq "0") {
            Write-Host "`n$FirstName $LastName ($studentID) is a new student but not provisioned in Powerschool yet.`nSkipping account creation..."
        }

        else {
            Write-Host "Specified student $Username ($studentID) does not exist, creating new account based on`nfields in Powerschool export..."

            $userOUtoAssign = "$studentGrade$siteName"
            $userGroupToAssign = $studentGroups[$user.schoolID]

            # SAM Account Names can only be 20 chars, this handles edge cases like kids with multiple first / last names
            # or names that run past the limit. 17 is the limit I set since it also accommodates for my duplicate handler.
            # ex: ReallyLongFirstName IsReallyReallyLong becomes Really Is.
            if ($Username.get_Length() -gt 20) {
                Write-Host "Username is too long, truncating extra names to start..."
                $FirstName = $FirstName -replace '([A-Z][a-z]*)[A-Z][a-z]*', '$1'
                $LastName = $LastName -replace '([A-Z][a-z]*)[A-Z][a-z]*', '$1'
                $Username = "$FirstName.$LastName"
                if ($Username.get_Length() -gt 17) {
                    $Username = $Username.Substring(0, [Math]::Min($Username.Length, 17))
                    Write-Host "`nUsername was still too long, forcing name length to 17 characters...`nNEW NAME: $Username`n"
                }
                else {
                    Write-Host "`nUsername successfully shortened...`nNEW NAME: $Username`n"
                }
            }

            # I went with this method to deal with duplicate names because 2 random digits would be too inconsistent and unreliable to deal with.
            # This should (in a perfect world) handle up to 10 kids with a duplicate name, as 0-9 will be the last digit of the lunch number.
            if ((Get-ADUser -F "SamAccountName -eq '$Username'" -Properties * | Select-Object -ExpandProperty SamAccountName)) {
               Write-Host "Username combo $Username already exists, appending initials and last lunch digit for UPN/SAM: `n"
               $Username = $Username + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID.Substring($studentID.get_Length() - 1)
               Write-Host "New Username: $Username`n"
               $LastName = $LastName + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID.Substring($studentID.get_Length() - 1)
            }

            try {
            New-ADUser `
                -Name $("$FirstName $LastName") `
                -GivenName $FirstName `
                -Path $userOUtoAssign `
                -Surname $LastName `
                -UserPrincipalName $("$Username@cowetaps.com") `
                -SamAccountName $Username `
                -EmployeeID $studentID `
                -DisplayName $("$FirstName $LastName") `
                -Department $siteName.Substring(3, 2) `
                -EmailAddress $("$FirstName.$LastName@cowetaps.org") `
                -Company "Coweta Public Schools" `
                -Title "Student" `
                -AccountPassword $(ConvertTo-SecureString $Password -AsPlainText -Force) `
                -ChangePasswordAtLogon $False `
                -PasswordNeverExpires $True `
                -Enabled $True

            Write-Host "CREATING ACCOUNT : $Username. `n`
            First Name: $FirstName`n`
            Last Name: $LastName`n`
            Email: $("$Username@cowetaps.org")`n`
            School Code: $($siteName.Substring(3, 2))`n`
            Company: $Company`n`
            Student ID: $studentID`n`
            Security Group: $userGroupToAssign`n"
            Write-Host "$userOUtoAssign is the OU for this account.`n`n"

            }

            catch {
                Write-Host "`nAccount for $FirstName $LastName ($studentID) was unable to be processed correctly. Skipping creation for this user...`n" 
            }

            try {
                Add-ADGroupMember -Identity $userGroupToAssign -Members $(Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName)
                Write-Host "Successfully able to join $Username to their site's group!`nGroup joined: $userGroupToAssign"
            }
            catch {
                Write-Host "Group join didn't work, skipping!"
            }
        }
   }    
} 

}

catch {
    Write-Host "Powerschool export CSV not found, please make sure your export file is in the same directory as the creation / manager scripts, and named correctly!"
}
