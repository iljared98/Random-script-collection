# Created by   : I. Jared
# Date Created : 5/8/2023
# Purpose      : Automating the creation of student accounts and grade promotions in AD.
Import-Module $PSScriptRoot\UDFs\iljFunctions.ps1 -Force

#! Do not change this file unless absolutely necessary.
#$PS_EXPORT_FILE = "AZAD_Students.csv"
$PS_EXPORT_FILE = "AZAD_Students_test.csv"

# Alternatively, execute these commands as administrator with a scheduled task : 
# powershell ".\studentCreation.ps1" > studentCreation.log
#$SC_LOGGING_FILE = "studentCreation.log"
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
#! -2 (Headstart), -1 (Pre-K).
$EXCLUDED_GRADES = @("-2", "-1")
#! PK-8 and 9-12 School for Blind (615 / 720), Grad students (999999)
$EXCLUDED_SITE_CODES = @("615", "720", "999999")

$usersToCreate = Import-CSV $PS_EXPORT_FILE

# TODO: By Michael's request, force group assignments for users in AD.

Write-Host "            ################################################`
            #    COWETA PUBLIC SCHOOLS STUDENT ACCOUNT     #`
            #                  GENERATOR                   #`
            #                                              #`
            ################################################"

# For logging / debugging purposes.
Write-Host "`nDATE: $(Get-Date -UFormat "%m/%d/%Y %R")`n"

foreach ($user in $usersToCreate) {

    # Aligning values from CSV columns to variables..
    $studentID = $user.studentNumber

    # Placeholders to remove annoying special characters; removing apostrophes, hyphens, and whitespace.
    $firstHolder = $user.firstName
    $lastHolder = $user.lastName

    # TODO: Strip extra first / last names (i.e. example-Name to exampleName to example) for simplicity's sake.
    $FirstName = $($firstHolder -replace "'","" -replace "-","" -replace " ","")
    $LastName = $($lastHolder -replace "'","" -replace "-","" -replace " ","")

    $studentGrade = $schoolGrades[$user.gradeLevel]
    $siteName = $schoolCodes[$user.schoolID] 

    $Username = "$FirstName.$LastName"

    # New student password convention. I had to add the exclamation point since Azure AD
    # complained about not having a special character for the passwords.
    #! Exclamation + first initial + last initial +  lunch # 
    $Password = "!" + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID
    $Company = "Coweta Public Schools"

    # Checks for duplicate users, using the employeeID field. If they already exist, update fields.
    if ((Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty EmployeeID)) {

        # Checks if student is in graduated school code, if they are, look to disable the account.
        if ($siteName -eq "Graduated Students") {

            # If disabled = true, skip account entirely.
            if ((Get-ADUser -F "employeeID -like $studentID" -Properties * | Select-Object -ExpandProperty Enabled) -eq $false) {
                Write-Host "Student account $studentID is already disabled. No longer processing the account..."
            }

            # Disable account, then skip after making a note.
            else {
                Write-Host "Student account $studentID is graduated but not disabled, disabling account and`n moving the`
                object to the DISABLED_STUDENTS container..."
                Get-ADUser -F "employeeID -eq $studentID" | Disable-ADAccount
                Get-ADUser -F "employeeID -eq $studentID" | Move-ADObject -TargetPath $DISABLED_OU
            }

        }

        # Updating fields that would be pertinent. 
        else {

            Write-Host "Student account for $FirstName $LastName ($studentID) already exists, updating fields in case of site changes..."

            $userObj = Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty SamAccountName
            $distName = Get-ADUser -F "employeeID -eq '$studentID'" -Properties * | Select-Object -ExpandProperty DistinguishedName

            # Substring(3, 2) extracts the 2 character site code for each OU.
            # i.e. Substring(3, 2) turns "OU=JH,OU=STUDENTS,DC=cowetaps,DC=com" into JH.
            #! Please ensure that all site containers still follow this 2 character convention
            #! to avoid errors or requiring a bunch of unnecessary refactoring.


            # Used to see if an account has a duped name already, if it does and a name change is needed, keep naming convention.
            $truncatedNameHolder = $($userObj -replace '^.*(?=.{3}$)').ToString()
            $appendedStringForDuplicates = $firstHolder.Substring(0, 1) + $lastHolder.Substring(0, 1) + $studentID.Substring($studentID.get_Length() - 1)

            if ($truncatedNameHolder -eq $appendedStringForDuplicates) {
                Write-Host "$userObj was initially created with a duplicate name, keeping former naming convention.."
                $Username = $Username + $appendedStringForDuplicates
            
                $userOUtoAssign = "$studentGrade$siteName"
            
                # TODO: Update ALL other fields as well
                Set-ADUser -Identity $userObj -Department $siteName.Substring(3, 2)
                Move-ADObject -Identity $distName -TargetPath $userOUtoAssign
                Write-Host "Moving $userObj to : $userOUtoAssign`n"
            }

            else {

                $userOUtoAssign = "$studentGrade$siteName"

                # TODO: Update ALL other fields as well
                Set-ADUser -Identity $userObj -Department $siteName.Substring(3, 2)
                Move-ADObject -Identity $distName -TargetPath $userOUtoAssign
                Write-Host "Moving $userObj to : $userOUtoAssign`n"
            }
        }
    }

    else {

        # Measure to prevent bad data from erroring out the script,
        # along with preventing the creation of accounts of certain grade levels / sites.
        if ($schoolCodes.Values -notcontains $siteName -or $schoolGrades.Values -notcontains $studentGrade) {
            Write-Host "`n$FirstName $LastName has an invalid grade level or school code. Skipping creation of this account..."

        }
        
        else {
            Write-Host "Specified student $Username ($studentID) does not exist, creating new account based on`nfields in Powerschool export..."

            $userOUtoAssign = "$studentGrade$siteName"



            # I went with this method to deal with duplicate names because 2 random digits would be too inconsistent and unreliable to deal with.
            # This should (in a perfect world) handle up to 10 kids with a duplicate name, as 0-9 will be the last digit of the lunch number.
            if ((Get-ADUser -F "SamAccountName -eq '$Username'" -Properties * | Select-Object -ExpandProperty SamAccountName)) {
               Write-Host "Username combo $Username already exists, appending initials and last lunch digit for UPN/SAM: `n"
               $Username = $Username + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID.Substring($studentID.get_Length() - 1)
               Write-Host "New Username: $Username`n"
               $LastName = $LastName + $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID.Substring($studentID.get_Length() - 1)
            }
        
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
                -EmailAddress $("$Username@cowetaps.org") `
                -Company "Coweta Public Schools" `
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
            Student ID: $studentID`n"
            Write-Host "$userOUtoAssign is the OU for this account.`n`n"

        }
   }    

} 
