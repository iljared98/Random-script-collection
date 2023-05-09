# Created by   : I. Jared
# Date Created : 5/8/2023
# Purpose      : Automating the creation of student accounts and grade promotions in AD.

#! Do not change this file unless absolutely necessary.
$PS_EXPORT_FILE = "export.csv"

# TODO: Robust logging of the student creation script.
# TODO: FIRST.LAST CONVENTION FOR NAMES
# TODO: FIRST LAST LUNCH NUMBER FOR PASS (DONE!)
# TODO: WRITEBACK INTO POWERSCHOOL FOR EMAIL ADDRESSES (i.e. make JOHN.DOE99@cowetaps.org. New process exports to a CSV, then writes back into PS Database)
# Alternatively, execute these commands as administrator with a scheduled task : 
# powershell ".\studentCreation.ps1" > studentCreation.log
$SC_LOGGING_FILE = "studentCreation.log"

### Data / rules used to correctly assign OUs as well as to update accounts correctly. ###
# School codes as they are defined in Powershool. I included all of them
# even though the "School for Blind" only seems to have 2-3 users across both sites??
# Need to confirm with Amy or Damon. Mapping these as a dict for now.
$schoolCodes = @{
    "705" = "HS"
    "710" = "IHS"
    "715" = "CAHS" # Academy students
    "610" = "OU=JH,OU=STUDENTS,DC=cowetaps,DC=com"
    "210" = "HIGC"
    "205" = "MIGC"
    "105" = "CE"
    "110" = "NW"
    "115" = "SS"
    "720" = "912SB" # 9-12 School for Blind
    "615" = "PK8SB" # PK-8 School for Blind
    "999999" = "Graduated Students" # TODO: Auto disable these accounts somehow.
}

# Dictionary of grade strings.
# -1 for Pre-K, 0 for K, rest should be obvious.
# OU=Users,OU=7TH,
$schoolGrades = @{
    "-1" = "OU=Users,OU=PK,"
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
### This section is meant to include excluded users and OUs 
# Array of UPNs to exclude from the update / promotion process.
$excludedUPNs = @("CE_STUDENT@cowetaps.com", "SS_STUDENT@cowetaps.com", "NW_Student@cowetaps.com")


foreach ($user in $usersToCreate) {

    # Grabs site name value 
    $siteName = $schoolCodes[$user.siteCode] # TODO: Verify this actually works. Also, correct fields
    # Aligning values from CSV columns to variables..
    $studentID = $user.STUDENTS_StudentID
    $FirstName = $user.STUDENTS_FirstName
    $LastName = $user.STUDENTS_LastName
    #$Username = $user.STUDENTS_StudentID 
    $siteName = $schoolCodes[$user.siteCode] # TODO: Verify this actually works. Also, correct fields
    $studentGrade = $schoolGrades[$user.studentGrade]

    # First init, last init, lunch # convention
    $Password = $FirstName.Substring(0, 1) + $LastName.Substring(0, 1) + $studentID

    # TODO: Force our user naming convention scheme into any new emails, then write them back into PS to avoid registrar errors.
    $Company = $user.company

    #! Putting into a try-catch block, as the script will likely get caught on an exception
    #! when comparing student IDs that do not exist.
    # Checks for duplicate users, using the employeeID field. If they already exist, update fields.
    try {
        if (Get-ADUser -F {EmployeeID -eq $EmployeeID}) {

            # Checks if student is in graduated school code, if they are, disables account
            if ($siteName -eq "Graduated Students") {

                # If disabled = true, skip account entirely.
               if ((Get-ADUser -F $EmployeeID -Properties * | Select-Object -ExpandProperty Enabled) -eq "False") {
                    Write-Host "Student account $EmployeeID is already disabled. No longer processing the account..."
               }

               # Disable account, then skip after making a note.
               else {
                Set-ADUser args or something 
               }
    
            }
    
            # Updating fields that would be pertinent. Might leave out the name change / email fields
            # just in case that would cause errors on our cloud tenant side of things.
            else {

                # Substring(3, 2) extracts the 2 character site code for each OU.
                # i.e. Substring(3, 2) turns "OU=JH,OU=STUDENTS,DC=cowetaps,DC=com" into JH.
                #! Please ensure that all site containers still follow this 2 character convention
                #! to avoid errors or requiring a bunch of unnecessary refactoring.
                Set-ADUser `
                -Name $("$FirstName $LastName") `
                -GivenName $FirstName `
                -Path $userOUtoAssign `
                -Surname $LastName `
                -UserPrincipalName $("$Username@cowetaps.com") `
                -EmployeeID $EmployeeID `
                -DisplayName $("$FirstName $LastName") `
                -Department $siteName.Substring(3, 2) `
                -EmailAddress $("") 
            }
        }
    }

    catch {
        Write-Host "Specified student ID $EmployeeID does not exist, creating new account based on`nfields in Powerschool export..."
         # TODO: Add logic branch here to fix duplicate names.
         $userOUtoAssign = "$studentGrade$siteName"
         # Currently Description maps to the variable $EmployeeType (certified/support). Change if we add a custom extended field later.
         if (1 -eq 1) {
            Write-Host "Username combo $Username already exists, appending random 2 digits for UPN/SAM: "
            $Username = "$Username$(Get-Random -Maximum 99)"
         }
         
         # For the time being, Description is being hijacked by : EMPLOYEE TYPE, or for students, [information that would be useful].
         New-ADUser `
             -Name $("$FirstName $LastName") `
             -GivenName $FirstName `
             -Path $userOUtoAssign `
             -Surname $LastName `
             -UserPrincipalName $("$Username@cowetaps.com") `
             -EmployeeID $EmployeeID `
             -DisplayName $("$FirstName $LastName") `
             -Department $siteName.Substring(3, 2) `
             -EmailAddress $EmailAddress `
             -Company $Company `
             -AccountPassword $(ConvertTo-SecureString $Password -AsPlainText -Force) `
             -ChangePasswordAtLogon $True `
             -Enabled $True
 
         Write-Host "CREATING ACCOUNT : $Username. `nFirstName: $FirstName`nLastName: $LastName`nPass: $Password`nEmail: $EmailAddress`nEmployeeType: $EmployeeType`nJobTitle: $JobTitle`nPrimaryLocation: $PrimaryLocation`nCompany: $Company`nEmpID: $EmployeeID`n"
         Write-Host "$userOUtoAssign is the OU for this account.`n`n"
    }

    # Get-ADUser -Filter "EmployeeID -eq 81902" -Properties * | Select-Object -ExpandProperty EmployeeID
    # Main magic that happens.
} # End of foreach
