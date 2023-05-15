# Created by   : I. Jared
# Date Created : 5/9/2023
# Purpose      : Check for graduated / transfer student accounts. Deletes specific disabled accounts after set cutoff date.
Import-Module $PSScriptRoot\UDFs\iljFunctions.ps1 -Force

#! Do not change this variable as it is the same CSV file that we use for student account creation.
$PS_EXPORT_FILE = "AZAD_Students.csv"

$AD_EXPORT_FILE = "ad_active_student_export.csv"

# TODO
# Also add test accounts to this array, as this script will export ALL ACTIVE ACCOUNTS from AD,
# these ensure that they are not accidentally moved to the disabled OU for future deletion.
$EXCLUDED_UPNS = @("CE_STUDENT@cowetaps.com", "SS_STUDENT@cowetaps.com", "NW_Student@cowetaps.com")

#! CHANGE AS NEEDED : Cutoff date for this script to delete Disabled_Students accounts.
$DELETION_DATE = "08/01"
# if ((Get-Date -UFormat "%m/%d") -eq $dateForDeletion)
#$STUDENT_ACCOUNTS = Import-CSV $PS_EXPORT_FILE


function Student-AccountNuker {
    Write-Host "I delete accounts :)"
    try {

    }

    catch {

    }
}

# TODO: Try to do the 90 days thing that Michael wants. Not even sure how we would do that since the request seems a bit weird and not straightforward anyways.
function Student-AccountDisabler {
    #try {
        Write-Host "Comparing AD export to PS export..."
        # $PS_EXPORT_FILE as reference.
        $usersToDisable = Compare-Object -Reference (Import-CSV $AD_EXPORT_FILE) -Difference (Import-CSV "AZAD_Students_test.csv") -Property $studentID `
        -PassThru | Sort-Object EmployeeID | Select-Object EmployeeID,SamAccountName

        #! Errors out due to permissions. Test first thing.
        foreach ($user in $users) {
            Get-ADUser -F "employeeID -like $($user.EmployeeID)" | Disable-ADAccount
            Write-Host "Disabled $($user.SamAccountName)"
        }

    #}

    #catch {
    #   write-host "something broke :("
    #}
}


function Main {
    try {
        Write-Host "Exporting currently active AD Student accounts to CSV...`nCleaning extra output..."

        # Using this chain of commands to remove the stupid type header / empty rows that get output by AD.
        Get-ADUser -Filter {Enabled -eq $true} -SearchBase "OU=STUDENTS,DC=cowetaps,DC=com"  -Properties * | Select-Object EmployeeID,`
        SamAccountName,Givenname,Surname | Sort-Object EmployeeID | Export-CSV -Path "temp.csv" -NoTypeInformation 

        Get-Content "temp.csv" | Where { $_.Replace(",","") -ne "" } | Out-File $AD_EXPORT_FILE

    }

    # Catch CSV or other write exception.
    catch {
        Warn-Print "ERROR: Please double-check to make sure that the CSV path is valid and / or that the account`
        executing this script has the proper permissions to said path.`n`nExiting with return code : -1"
        Return -1

    }

    Write-Host "`nInitiating disabling of graduated and transferred student accounts..."
    Student-AccountDisabler

}

#! Do not remove this function call.
Main
